import Foundation

// MARK: - Configuration Models

struct ConversionConfig: Codable {
    let output: OutputConfig
    let specialCharacters: [SpecialCharacter]
    let replacements: [Replacement]
    let quoteDetection: QuoteDetection
    let codeSnippets: [ConfigCodeSnippet]

    enum CodingKeys: String, CodingKey {
        case output
        case specialCharacters = "special_characters"
        case replacements
        case quoteDetection = "quote_detection"
        case codeSnippets = "code_snippets"
    }
}

struct OutputConfig: Codable {
    let paragraphTag: String
    let headingTag: String

    enum CodingKeys: String, CodingKey {
        case paragraphTag = "paragraph_tag"
        case headingTag = "heading_tag"
    }
}

struct SpecialCharacter: Codable {
    let character: String
    let wrapTag: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case character
        case wrapTag = "wrap_tag"
        case enabled
    }
}

struct Replacement: Codable {
    let search: String
    let replace: String
    let caseSensitive: Bool

    enum CodingKeys: String, CodingKey {
        case search
        case replace
        case caseSensitive = "case_sensitive"
    }
}

struct QuoteDetection: Codable {
    let enabled: Bool
    let threshold: Int
    let wrapTag: String
    let quoteTypes: [String]

    enum CodingKeys: String, CodingKey {
        case enabled
        case threshold
        case wrapTag = "wrap_tag"
        case quoteTypes = "quote_types"
    }
}

struct ConfigCodeSnippet: Codable {
    let name: String
    let file: String
    let enabled: Bool
}

// MARK: - DOCX XML Models

enum ListType {
    case bullet
    case numbered
}

struct ListItem {
    let level: Int
    let type: ListType
    let text: String
}

// MARK: - Main Converter

class DocxConverter {
    let config: ConversionConfig

    init(config: ConversionConfig) {
        self.config = config
    }

    func convert(docxURL: URL) throws -> String {
        // Extract DOCX (it's a ZIP file)
        let tempDir = try extractDocx(from: docxURL)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Parse document.xml
        let documentXMLPath = tempDir.appendingPathComponent("word/document.xml")
        let documentData = try Data(contentsOf: documentXMLPath)
        let xmlDoc = try XMLDocument(data: documentData)

        // Get relationships for hyperlinks
        let relsPath = tempDir.appendingPathComponent("word/_rels/document.xml.rels")
        let relationships = try parseRelationships(at: relsPath)

        // Process document body
        guard let bodyElement = try xmlDoc.rootElement()?.nodes(forXPath: "//w:body").first as? XMLElement else {
            throw ConversionError.missingBody
        }

        var htmlParts: [String] = []
        var currentListItems: [ListItem] = []

        // Process each element in the body
        for child in bodyElement.children ?? [] {
            guard let element = child as? XMLElement else { continue }

            let name = element.localName ?? ""

            switch name {
            case "p": // Paragraph
                let paragraph = try processParagraph(element, relationships: relationships)

                if let listItem = paragraph.listItem {
                    // This is a list item
                    currentListItems.append(listItem)
                } else {
                    // Close any open list
                    if !currentListItems.isEmpty {
                        htmlParts.append(createListHTML(from: currentListItems))
                        currentListItems.removeAll()
                    }

                    // Add regular paragraph
                    if let html = paragraph.html {
                        htmlParts.append(html)
                    }
                }

            case "tbl": // Table
                // Close any open list
                if !currentListItems.isEmpty {
                    htmlParts.append(createListHTML(from: currentListItems))
                    currentListItems.removeAll()
                }

                let tableHTML = try processTable(element)
                if !tableHTML.isEmpty {
                    htmlParts.append(tableHTML)
                }

            default:
                break
            }
        }

        // Close any remaining list
        if !currentListItems.isEmpty {
            htmlParts.append(createListHTML(from: currentListItems))
        }

        // Join all parts
        var html = htmlParts.joined(separator: "\n")

        // Apply transformations
        html = applySpecialCharacters(to: html)
        html = applyReplacements(to: html)

        return html
    }

    // MARK: - DOCX Extraction

    private func extractDocx(from url: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Use unzip command to extract
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", tempDir.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ConversionError.extractionFailed
        }

        return tempDir
    }

    // MARK: - Relationship Parsing

    private func parseRelationships(at url: URL) throws -> [String: String] {
        var relationships: [String: String] = [:]

        guard FileManager.default.fileExists(atPath: url.path) else {
            return relationships
        }

        let data = try Data(contentsOf: url)
        let xmlDoc = try XMLDocument(data: data)

        // Get all Relationship elements
        let relElements = try xmlDoc.rootElement()?.nodes(forXPath: "//Relationship") as? [XMLElement] ?? []

        for rel in relElements {
            if let id = rel.attribute(forName: "Id")?.stringValue,
               let target = rel.attribute(forName: "Target")?.stringValue {
                relationships[id] = target
            }
        }

        return relationships
    }

    // MARK: - Paragraph Processing

    struct ParagraphResult {
        let html: String?
        let listItem: ListItem?
    }

    private func processParagraph(_ element: XMLElement, relationships: [String: String]) throws -> ParagraphResult {
        // Check if it's a list item
        if let listItem = extractListInfo(from: element) {
            let text = try processRuns(in: element, relationships: relationships)
            return ParagraphResult(html: nil, listItem: ListItem(level: listItem.level, type: listItem.type, text: text))
        }

        // Get paragraph text
        let text = getElementText(element)
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ParagraphResult(html: nil, listItem: nil)
        }

        // Check if it's a heading
        let isHeading = isHeadingStyle(element)
        let tag = isHeading ? config.output.headingTag : config.output.paragraphTag

        // Process runs for formatting and hyperlinks
        let htmlContent = try processRuns(in: element, relationships: relationships)

        // Check for quote detection
        if config.quoteDetection.enabled {
            let quoteCount = countQuotes(in: text)
            if quoteCount >= config.quoteDetection.threshold {
                let (openTag, closeTag) = parseWrapTag(config.quoteDetection.wrapTag)
                return ParagraphResult(html: "\(openTag)<\(tag)>\(htmlContent)</\(tag)>\(closeTag)", listItem: nil)
            }
        }

        return ParagraphResult(html: "<\(tag)>\(htmlContent)</\(tag)>", listItem: nil)
    }

    private func processRuns(in paragraph: XMLElement, relationships: [String: String]) throws -> String {
        var result: [String] = []

        // Extract all hyperlinks first (maps hyperlink elements to their URLs)
        let hyperlinkMap = extractHyperlinkMap(from: paragraph, relationships: relationships)

        // Process all children in order (this gives us proper positioning!)
        for child in paragraph.children ?? [] {
            guard let element = child as? XMLElement else { continue }

            let name = element.localName ?? ""

            if name == "hyperlink" {
                // Process hyperlink element with all its runs
                if let url = hyperlinkMap[element] {
                    let text = getElementText(element)
                    result.append(formatLink(url: url, text: text))
                }
            } else if name == "r" {
                // Regular run (not inside a hyperlink)
                let runHTML = processRun(element)
                if !runHTML.isEmpty {
                    result.append(runHTML)
                }
            }
        }

        return result.joined()
    }

    private func processRun(_ runElement: XMLElement) -> String {
        // Get text content
        let text = getRunText(runElement)

        // Skip empty runs
        guard !text.isEmpty else { return "" }

        // Get formatting
        let isBold = hasFormatting(runElement, tag: "b") || hasFormatting(runElement, tag: "bCs")
        let isItalic = hasFormatting(runElement, tag: "i") || hasFormatting(runElement, tag: "iCs")
        let isUnderline = hasFormatting(runElement, tag: "u")

        var formatted = escapeHTML(text)

        if isUnderline {
            formatted = "<u>\(formatted)</u>"
        }
        if isItalic {
            formatted = "<em>\(formatted)</em>"
        }
        if isBold {
            formatted = "<strong>\(formatted)</strong>"
        }

        return formatted
    }

    // MARK: - Hyperlink Processing

    private func extractHyperlinkMap(from paragraph: XMLElement, relationships: [String: String]) -> [XMLElement: String] {
        var hyperlinkMap: [XMLElement: String] = [:]

        // Find all hyperlink elements
        let hyperlinkElements = (try? paragraph.nodes(forXPath: "./w:hyperlink")) as? [XMLElement] ?? []

        for hyperlink in hyperlinkElements {
            if let rId = hyperlink.attribute(forName: "r:id")?.stringValue,
               let url = relationships[rId] {
                hyperlinkMap[hyperlink] = url
            } else if let anchor = hyperlink.attribute(forName: "w:anchor")?.stringValue {
                hyperlinkMap[hyperlink] = "#\(anchor)"
            }
        }

        return hyperlinkMap
    }

    private func formatLink(url: String, text: String) -> String {
        return "<a href=\"\(url)\">\(escapeHTML(text))</a>"
    }

    // MARK: - List Processing

    private func extractListInfo(from paragraph: XMLElement) -> (level: Int, type: ListType)? {
        // Look for numPr element which indicates a list
        guard let numPr = (try? paragraph.nodes(forXPath: ".//w:numPr").first) as? XMLElement else {
            return nil
        }

        // Get list level
        let levelElement = (try? numPr.nodes(forXPath: ".//w:ilvl").first) as? XMLElement
        let levelValue = levelElement?.attribute(forName: "w:val")?.stringValue ?? "0"
        let level = Int(levelValue) ?? 0

        // For now, default to bullet (we could enhance this by reading numbering.xml)
        return (level: level, type: .bullet)
    }

    private func createListHTML(from items: [ListItem]) -> String {
        guard !items.isEmpty else { return "" }

        let minLevel = items.map { $0.level }.min() ?? 0
        let (html, _) = buildNestedList(items: items, startIndex: 0, currentLevel: minLevel)
        return html
    }

    private func buildNestedList(items: [ListItem], startIndex: Int, currentLevel: Int) -> (String, Int) {
        guard startIndex < items.count else { return ("", startIndex) }

        var htmlParts: [String] = []
        var i = startIndex
        var currentListType: ListType?
        var listStarted = false

        while i < items.count {
            let item = items[i]

            if item.level < currentLevel {
                // Going back up - close current list
                if listStarted, let type = currentListType {
                    let tag = type == .bullet ? "ul" : "ol"
                    htmlParts.append("</\(tag)>")
                }
                return (htmlParts.joined(separator: "\n"), i)
            } else if item.level == currentLevel {
                // Same level - add list item
                if !listStarted {
                    currentListType = item.type
                    let tag = item.type == .bullet ? "ul" : "ol"
                    htmlParts.append("<\(tag)>")
                    listStarted = true
                }

                // Check if next item is nested
                if i + 1 < items.count && items[i + 1].level > item.level {
                    htmlParts.append("  <li>\(item.text)")
                    let (nestedHTML, nextIndex) = buildNestedList(items: items, startIndex: i + 1, currentLevel: items[i + 1].level)
                    let indented = nestedHTML.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n")
                    htmlParts.append(indented)
                    htmlParts.append("  </li>")
                    i = nextIndex
                } else {
                    htmlParts.append("  <li>\(item.text)</li>")
                    i += 1
                }
            } else {
                break
            }
        }

        if listStarted, let type = currentListType {
            let tag = type == .bullet ? "ul" : "ol"
            htmlParts.append("</\(tag)>")
        }

        return (htmlParts.joined(separator: "\n"), i)
    }

    // MARK: - Table Processing

    private func processTable(_ element: XMLElement) throws -> String {
        // Get table rows by filtering direct children
        let rows = element.children?.compactMap { $0 as? XMLElement }.filter { $0.localName == "tr" } ?? []
        guard !rows.isEmpty else { return "" }

        var htmlParts = ["<table>"]

        // First row as header
        if let firstRow = rows.first {
            htmlParts.append("  <thead>")
            htmlParts.append("    <tr>")

            let cells = firstRow.children?.compactMap { $0 as? XMLElement }.filter { $0.localName == "tc" } ?? []
            for cell in cells {
                let cellText = escapeHTML(getCellText(cell).trimmingCharacters(in: .whitespaces))
                htmlParts.append("      <th>\(cellText)</th>")
            }

            htmlParts.append("    </tr>")
            htmlParts.append("  </thead>")
        }

        // Rest as body
        if rows.count > 1 {
            htmlParts.append("  <tbody>")

            for row in rows.dropFirst() {
                htmlParts.append("    <tr>")

                let cells = row.children?.compactMap { $0 as? XMLElement }.filter { $0.localName == "tc" } ?? []
                for cell in cells {
                    let cellText = escapeHTML(getCellText(cell).trimmingCharacters(in: .whitespaces))
                    htmlParts.append("      <td>\(cellText)</td>")
                }

                htmlParts.append("    </tr>")
            }

            htmlParts.append("  </tbody>")
        }

        htmlParts.append("</table>")

        return htmlParts.joined(separator: "\n")
    }

    private func getCellText(_ cell: XMLElement) -> String {
        // Get only direct paragraph children of the cell
        let paragraphs = cell.children?.compactMap { $0 as? XMLElement }.filter { $0.localName == "p" } ?? []

        // Extract text directly from runs in each paragraph
        var cellTexts: [String] = []
        for paragraph in paragraphs {
            let runs = paragraph.children?.compactMap { $0 as? XMLElement }.filter { $0.localName == "r" } ?? []
            let paragraphText = runs.map { extractTextFromRun($0) }.joined()
            if !paragraphText.isEmpty {
                cellTexts.append(paragraphText)
            }
        }

        return cellTexts.joined(separator: " ")
    }

    private func extractTextFromRun(_ runElement: XMLElement) -> String {
        // Extract text by traversing only direct children
        var texts: [String] = []

        func traverse(_ element: XMLElement) {
            if element.localName == "t" {
                if let text = element.stringValue {
                    texts.append(text)
                }
            } else {
                // Recursively check children for <w:t> elements
                for child in element.children ?? [] {
                    if let childElement = child as? XMLElement {
                        traverse(childElement)
                    }
                }
            }
        }

        traverse(runElement)
        return texts.joined()
    }

    // MARK: - Transformations

    private func applySpecialCharacters(to html: String) -> String {
        var result = html

        for special in config.specialCharacters where special.enabled {
            let pattern = NSRegularExpression.escapedPattern(for: special.character)
            result = result.replacingOccurrences(
                of: pattern,
                with: "<\(special.wrapTag)>\(special.character)</\(special.wrapTag)>",
                options: .regularExpression
            )
        }

        return result
    }

    private func applyReplacements(to html: String) -> String {
        var result = html

        for replacement in config.replacements {
            // Apply replacements only to text content, not within HTML tags
            result = replaceOutsideTags(
                in: result,
                search: replacement.search,
                replace: replacement.replace,
                caseSensitive: replacement.caseSensitive
            )
        }

        return result
    }

    private func replaceOutsideTags(in html: String, search: String, replace: String, caseSensitive: Bool) -> String {
        var result = ""
        var insideTag = false
        var currentText = ""

        for char in html {
            if char == "<" {
                // Process accumulated text before entering tag
                if !currentText.isEmpty {
                    if caseSensitive {
                        result += currentText.replacingOccurrences(of: search, with: replace)
                    } else {
                        result += currentText.replacingOccurrences(of: search, with: replace, options: .caseInsensitive)
                    }
                    currentText = ""
                }
                insideTag = true
                result.append(char)
            } else if char == ">" {
                insideTag = false
                result.append(char)
            } else if insideTag {
                // Inside tag - don't replace, just append
                result.append(char)
            } else {
                // Outside tag - accumulate text
                currentText.append(char)
            }
        }

        // Process any remaining text
        if !currentText.isEmpty {
            if caseSensitive {
                result += currentText.replacingOccurrences(of: search, with: replace)
            } else {
                result += currentText.replacingOccurrences(of: search, with: replace, options: .caseInsensitive)
            }
        }

        return result
    }

    // MARK: - Helper Methods

    private func getElementText(_ element: XMLElement) -> String {
        let textNodes = (try? element.nodes(forXPath: ".//w:t")) as? [XMLElement] ?? []
        return textNodes.compactMap { $0.stringValue }.joined()
    }

    private func getRunText(_ runElement: XMLElement) -> String {
        let textNodes = (try? runElement.nodes(forXPath: ".//w:t")) as? [XMLElement] ?? []
        return textNodes.compactMap { $0.stringValue }.joined()
    }

    private func hasFormatting(_ runElement: XMLElement, tag: String) -> Bool {
        let path = ".//w:\(tag)"
        let nodes = (try? runElement.nodes(forXPath: path)) as? [XMLElement] ?? []
        return !nodes.isEmpty
    }

    private func isHeadingStyle(_ paragraph: XMLElement) -> Bool {
        let styleNodes = (try? paragraph.nodes(forXPath: ".//w:pStyle")) as? [XMLElement] ?? []
        for style in styleNodes {
            if let val = style.attribute(forName: "w:val")?.stringValue,
               val.hasPrefix("Heading") {
                return true
            }
        }
        return false
    }

    private func countQuotes(in text: String) -> Int {
        return config.quoteDetection.quoteTypes.reduce(0) { count, quoteType in
            count + text.components(separatedBy: quoteType).count - 1
        }
    }

    private func parseWrapTag(_ wrapTag: String) -> (String, String) {
        let trimmed = wrapTag.trimmingCharacters(in: .whitespaces)

        if trimmed.contains(" ") {
            // Has attributes
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            let tagName = String(parts[0])
            return ("<\(trimmed)>", "</\(tagName)>")
        } else {
            // Simple tag
            return ("<\(trimmed)>", "</\(trimmed)>")
        }
    }

    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - Errors

enum ConversionError: LocalizedError {
    case extractionFailed
    case missingBody
    case invalidXML

    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Failed to extract DOCX file"
        case .missingBody:
            return "Document body not found"
        case .invalidXML:
            return "Invalid XML structure"
        }
    }
}
