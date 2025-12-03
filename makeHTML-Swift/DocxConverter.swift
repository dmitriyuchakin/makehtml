import Foundation

// MARK: - Validation Models

/// Result of validation comparing DOCX plain text to HTML output
struct ValidationResult {
    let isValid: Bool
    let differences: [TextDifference]
    let docxText: String
    let htmlText: String
}

/// Type of difference found during validation
enum DifferenceType {
    case missing    // Text present in DOCX but missing from HTML
    case extra      // Extra text in HTML not present in DOCX
    case different  // Text differs between DOCX and HTML
}

/// Represents a difference found during validation
struct TextDifference {
    let type: DifferenceType
    let position: Int
    let expected: String?  // Text from DOCX
    let actual: String?    // Text from HTML
}

// MARK: - Configuration Models

struct ConversionConfig: Codable {
    let output: OutputConfig
    let specialCharacters: [SpecialCharacter]
    let replacements: [Replacement]
    let quoteDetection: QuoteDetection
    let linkHandling: LinkHandling
    let codeSnippets: [ConfigCodeSnippet]
    let tidyFormatting: TidyFormatting?  // Optional for backward compatibility

    enum CodingKeys: String, CodingKey {
        case output
        case specialCharacters = "special_characters"
        case replacements
        case quoteDetection = "quote_detection"
        case linkHandling = "link_handling"
        case codeSnippets = "code_snippets"
        case tidyFormatting = "tidy_formatting"
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

struct LinkHandling: Codable {
    let enabled: Bool
    let addTargetBlank: Bool
    let exceptionDomains: [String]

    enum CodingKeys: String, CodingKey {
        case enabled
        case addTargetBlank = "add_target_blank"
        case exceptionDomains = "exception_domains"
    }
}

struct ConfigCodeSnippet: Codable {
    let name: String
    let file: String
    let enabled: Bool
}

struct TidyFormatting: Codable {
    let enabled: Bool
    let indentSpaces: Int
    let wrapLength: Int
    let verticalSpace: Bool
    let showBodyOnly: Bool
    let customOptions: [String]?  // Array of additional tidy command-line options

    enum CodingKeys: String, CodingKey {
        case enabled
        case indentSpaces = "indent_spaces"
        case wrapLength = "wrap_length"
        case verticalSpace = "vertical_space"
        case showBodyOnly = "show_body_only"
        case customOptions = "custom_options"
    }
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
        let document = try parseDocument(from: docxURL)
        return try renderDocument(document)
    }

    func extractPlainText(docxURL: URL) throws -> String {
        let document = try parseDocument(from: docxURL)
        return extractPlainTextFromDocument(document)
    }

    private func parseDocument(from docxURL: URL) throws -> DocxDocument {
        // Extract DOCX (it's a ZIP file)
        let tempDir = try extractDocx(from: docxURL)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Parse document.xml
        let documentXMLPath = tempDir.appendingPathComponent("word/document.xml")
        let documentData = try Data(contentsOf: documentXMLPath)

        // Get relationships for hyperlinks
        let relsPath = tempDir.appendingPathComponent("word/_rels/document.xml.rels")
        let relationships = try parseRelationships(at: relsPath)

        // Parse document using XMLParser (preserves whitespace!)
        let parser = DocxXMLParser()
        return try parser.parse(documentData: documentData, relationships: relationships)
    }

    private func renderDocument(_ document: DocxDocument) throws -> String {

        // Convert parsed document to HTML
        var htmlParts: [String] = []
        var currentListItems: [ListItem] = []

        for element in document.elements {
            switch element {
            case .paragraph(let paragraph):
                // Check if it's a list item
                if let listLevel = paragraph.listLevel {
                    let text = renderParagraphContents(paragraph.contents)
                    let type: ListType = paragraph.listType == "numbered" ? .numbered : .bullet
                    currentListItems.append(ListItem(level: listLevel, type: type, text: text))
                } else {
                    // Close any open list
                    if !currentListItems.isEmpty {
                        htmlParts.append(createListHTML(from: currentListItems))
                        currentListItems.removeAll()
                    }

                    // Add regular paragraph
                    let html = renderParagraph(paragraph)
                    if !html.isEmpty {
                        htmlParts.append(html)
                    }
                }

            case .table(let table):
                // Close any open list
                if !currentListItems.isEmpty {
                    htmlParts.append(createListHTML(from: currentListItems))
                    currentListItems.removeAll()
                }

                let tableHTML = renderTable(table)
                if !tableHTML.isEmpty {
                    htmlParts.append(tableHTML)
                }
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

        // Format HTML with LibTidy
        html = formatHTML(html)

        return html
    }

    // MARK: - HTML Formatting

    /// Format HTML using bundled tidy binary for clean, consistent output
    private func formatHTML(_ html: String) -> String {
        // Check if tidy formatting is enabled in config
        guard let tidyConfig = config.tidyFormatting, tidyConfig.enabled else {
            // Tidy formatting is disabled, return original HTML
            return html
        }

        // Try to find bundled tidy binary first
        var tidyPath: String?

        // Check if tidy is bundled in app resources
        if let resourcePath = Bundle.main.resourcePath {
            let bundledTidy = "\(resourcePath)/tidy"
            if FileManager.default.fileExists(atPath: bundledTidy) {
                tidyPath = bundledTidy
            }
        }

        // Fallback to system tidy if bundled version not found
        if tidyPath == nil {
            tidyPath = "/opt/homebrew/bin/tidy"

            // Check if system tidy exists
            if !FileManager.default.fileExists(atPath: tidyPath!) {
                // Try alternate locations
                let alternatePaths = [
                    "/usr/local/bin/tidy",
                    "/usr/bin/tidy"
                ]

                for path in alternatePaths {
                    if FileManager.default.fileExists(atPath: path) {
                        tidyPath = path
                        break
                    }
                }
            }
        }

        guard let validTidyPath = tidyPath,
              FileManager.default.fileExists(atPath: validTidyPath) else {
            // If tidy not found, return original HTML
            return html
        }

        // Build tidy arguments from config
        var arguments: [String] = [
            "--indent", "auto",
            "--indent-spaces", "\(tidyConfig.indentSpaces)",
            "--wrap", "\(tidyConfig.wrapLength)",
            "--quiet", "yes",
            "--show-warnings", "no",
            "--drop-empty-elements", "no",
            "--tidy-mark", "no"
        ]

        // Add vertical space option
        if tidyConfig.verticalSpace {
            arguments += ["--vertical-space", "yes"]
        } else {
            arguments += ["--vertical-space", "no"]
        }

        // Add show-body-only option
        if tidyConfig.showBodyOnly {
            arguments += ["--show-body-only", "yes"]
        } else {
            arguments += ["--show-body-only", "no"]
        }

        // Add custom options if provided
        if let customOptions = tidyConfig.customOptions {
            arguments += customOptions
        }

        // Run tidy on the HTML
        let process = Process()
        process.executableURL = URL(fileURLWithPath: validTidyPath)
        process.arguments = arguments

        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = Pipe()  // Discard errors

        do {
            try process.run()

            // Write HTML to stdin
            if let data = html.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
                inputPipe.fileHandleForWriting.closeFile()
            }

            // Read formatted output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if let formatted = String(data: outputData, encoding: .utf8),
               !formatted.isEmpty {
                return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // If tidy fails, return original HTML
            return html
        }

        return html
    }

    private func extractPlainTextFromDocument(_ document: DocxDocument) -> String {
        var textParts: [String] = []

        for element in document.elements {
            switch element {
            case .paragraph(let paragraph):
                let text = extractPlainTextFromParagraph(paragraph)
                if !text.isEmpty {
                    textParts.append(text)
                }

            case .table(let table):
                for row in table.rows {
                    for cell in row.cells {
                        if !cell.text.isEmpty {
                            textParts.append(cell.text)
                        }
                    }
                }
            }
        }

        return textParts.joined(separator: "\n")
    }

    private func extractPlainTextFromParagraph(_ paragraph: DocxParagraph) -> String {
        var texts: [String] = []

        for content in paragraph.contents {
            switch content {
            case .run(let run):
                texts.append(run.text)
            case .hyperlink(let hyperlink):
                texts.append(hyperlink.text)
            }
        }

        return texts.joined()
    }

    // MARK: - Validation

    func validateConversion(docxURL: URL, htmlOutput: String) throws -> ValidationResult {
        // Extract plain text from DOCX
        let docxPlainText = try extractPlainText(docxURL: docxURL)

        // Extract plain text from HTML
        let htmlPlainText = stripHTMLTags(from: htmlOutput)

        // Normalize whitespace for comparison (collapse multiple spaces/newlines)
        let normalizedDocx = normalizeWhitespace(docxPlainText)
        let normalizedHTML = normalizeWhitespace(htmlPlainText)

        // Compare
        if normalizedDocx == normalizedHTML {
            return ValidationResult(isValid: true, differences: [], docxText: docxPlainText, htmlText: htmlPlainText)
        } else {
            let diffs = findDifferences(expected: normalizedDocx, actual: normalizedHTML)
            return ValidationResult(isValid: false, differences: diffs, docxText: docxPlainText, htmlText: htmlPlainText)
        }
    }

    private func stripHTMLTags(from html: String) -> String {
        var result = ""
        var insideTag = false

        for char in html {
            if char == "<" {
                insideTag = true
            } else if char == ">" {
                insideTag = false
            } else if !insideTag {
                result.append(char)
            }
        }

        // Decode HTML entities
        return decodeHTMLEntities(result)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // Common HTML entities
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " "
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }

    private func normalizeWhitespace(_ text: String) -> String {
        // Collapse multiple spaces/newlines to single space
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func findDifferences(expected: String, actual: String) -> [TextDifference] {
        var differences: [TextDifference] = []

        let expectedChars = Array(expected)
        let actualChars = Array(actual)
        let maxLen = max(expectedChars.count, actualChars.count)

        var i = 0
        while i < maxLen {
            if i >= expectedChars.count {
                // Extra characters in actual
                let endIndex = min(i + 50, actualChars.count)
                let extraText = String(actualChars[i..<endIndex])
                differences.append(TextDifference(
                    type: .extra,
                    position: i,
                    expected: nil,
                    actual: extraText
                ))
                break
            } else if i >= actualChars.count {
                // Missing characters in actual
                let endIndex = min(i + 50, expectedChars.count)
                let missingText = String(expectedChars[i..<endIndex])
                differences.append(TextDifference(
                    type: .missing,
                    position: i,
                    expected: missingText,
                    actual: nil
                ))
                break
            } else if expectedChars[i] != actualChars[i] {
                // Different character
                let contextStart = max(0, i - 20)
                let contextEnd = min(i + 20, min(expectedChars.count, actualChars.count))
                let expectedContext = String(expectedChars[contextStart..<contextEnd])
                let actualContext = String(actualChars[contextStart..<contextEnd])

                differences.append(TextDifference(
                    type: .different,
                    position: i,
                    expected: expectedContext,
                    actual: actualContext
                ))

                // Skip ahead to avoid reporting every character in a mismatched section
                i += 20
            }

            i += 1
        }

        return differences
    }

    // MARK: - Rendering Functions (XMLParser-based)

    private func renderParagraph(_ paragraph: DocxParagraph) -> String {
        let content = renderParagraphContents(paragraph.contents)

        // Skip empty paragraphs
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        let tag = paragraph.isHeading ? config.output.headingTag : config.output.paragraphTag

        // Check for quote detection
        if config.quoteDetection.enabled {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if shouldWrapAsQuote(trimmed) {
                let openTag = "<\(config.quoteDetection.wrapTag)>"
                let closeTag = "</\(config.quoteDetection.wrapTag.split(separator: " ").first ?? "div")>"
                return "\(openTag)<\(tag)>\(content)</\(tag)>\(closeTag)"
            }
        }

        return "<\(tag)>\(content)</\(tag)>"
    }

    private func renderParagraphContents(_ contents: [DocxParagraphContent]) -> String {
        // First, merge consecutive runs with identical formatting
        let mergedContents = mergeConsecutiveRuns(contents)

        var result: [String] = []

        for content in mergedContents {
            switch content {
            case .run(let run):
                result.append(renderRun(run))
            case .hyperlink(let hyperlink):
                result.append(formatLink(url: hyperlink.url, text: hyperlink.text))
            }
        }

        return result.joined()
    }

    /// Merge consecutive runs that have identical formatting
    /// This prevents output like <strong>A</strong><strong>B</strong> and instead produces <strong>AB</strong>
    private func mergeConsecutiveRuns(_ contents: [DocxParagraphContent]) -> [DocxParagraphContent] {
        guard !contents.isEmpty else { return contents }

        var merged: [DocxParagraphContent] = []
        var currentRun: DocxRun?

        for content in contents {
            switch content {
            case .run(let run):
                if let current = currentRun {
                    // Check if formatting matches
                    if current.isBold == run.isBold &&
                       current.isItalic == run.isItalic &&
                       current.isUnderline == run.isUnderline &&
                       current.isSuperscript == run.isSuperscript &&
                       current.isSubscript == run.isSubscript {
                        // Same formatting - merge the text
                        currentRun = DocxRun(
                            text: current.text + run.text,
                            isBold: current.isBold,
                            isItalic: current.isItalic,
                            isUnderline: current.isUnderline,
                            isSuperscript: current.isSuperscript,
                            isSubscript: current.isSubscript
                        )
                    } else {
                        // Different formatting - save current and start new
                        merged.append(.run(current))
                        currentRun = run
                    }
                } else {
                    // First run
                    currentRun = run
                }

            case .hyperlink(let hyperlink):
                // Save any pending run first
                if let current = currentRun {
                    merged.append(.run(current))
                    currentRun = nil
                }
                // Add the hyperlink
                merged.append(.hyperlink(hyperlink))
            }
        }

        // Don't forget the last run
        if let current = currentRun {
            merged.append(.run(current))
        }

        return merged
    }

    private func renderRun(_ run: DocxRun) -> String {
        // Handle empty text
        guard !run.text.isEmpty else {
            return ""
        }

        // For whitespace-only runs, just escape and return
        let trimmed = run.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return escapeHTML(run.text)
        }

        var formatted = escapeHTML(run.text)

        // Apply formatting
        if run.isSuperscript {
            formatted = "<sup>\(formatted)</sup>"
        } else if run.isSubscript {
            formatted = "<sub>\(formatted)</sub>"
        }

        if run.isUnderline {
            formatted = "<u>\(formatted)</u>"
        }
        if run.isItalic {
            formatted = "<em>\(formatted)</em>"
        }
        if run.isBold {
            formatted = "<strong>\(formatted)</strong>"
        }

        return formatted
    }

    private func renderTable(_ table: DocxTable) -> String {
        guard !table.rows.isEmpty else {
            return ""
        }

        var htmlParts = ["<table>"]

        // First row as header
        if let firstRow = table.rows.first {
            htmlParts.append("  <thead>")
            htmlParts.append("    <tr>")

            for cell in firstRow.cells {
                let cellText = escapeHTML(cell.text.trimmingCharacters(in: .whitespacesAndNewlines))
                htmlParts.append("      <th>\(cellText)</th>")
            }

            htmlParts.append("    </tr>")
            htmlParts.append("  </thead>")
        }

        // Rest as body
        if table.rows.count > 1 {
            htmlParts.append("  <tbody>")

            for row in table.rows.dropFirst() {
                htmlParts.append("    <tr>")

                for cell in row.cells {
                    let cellText = escapeHTML(cell.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    htmlParts.append("      <td>\(cellText)</td>")
                }

                htmlParts.append("    </tr>")
            }

            htmlParts.append("  </tbody>")
        }

        htmlParts.append("</table>")

        return htmlParts.joined(separator: "\n")
    }

    private func shouldWrapAsQuote(_ text: String) -> Bool {
        // Extract only the text content (not HTML tags/attributes) for quote counting
        var textOnly = ""
        var insideTag = false

        for char in text {
            if char == "<" {
                insideTag = true
            } else if char == ">" {
                insideTag = false
            } else if !insideTag {
                textOnly.append(char)
            }
        }

        // Count quote characters only in text content
        let quoteCount = config.quoteDetection.quoteTypes.reduce(0) { count, quoteChar in
            count + textOnly.filter { String($0) == quoteChar }.count
        }
        return quoteCount >= config.quoteDetection.threshold
    }

    private func formatLink(url: String, text: String) -> String {
        var attributes = "href=\"\(url)\""

        // Add target="_blank" if link_handling is enabled
        if config.linkHandling.enabled && config.linkHandling.addTargetBlank {
            // Check if this domain is in the exception list
            if !isDomainExcluded(url: url) {
                attributes += " target=\"_blank\""
            }
        }

        return "<a \(attributes)>\(escapeHTML(text))</a>"
    }

    private func isDomainExcluded(url: String) -> Bool {
        // Extract domain from URL
        guard let urlObj = URL(string: url),
              let host = urlObj.host else {
            return false
        }

        // Check if host matches any exception domain
        for exceptionDomain in config.linkHandling.exceptionDomains {
            if host == exceptionDomain || host.hasSuffix(".\(exceptionDomain)") {
                return true
            }
        }

        return false
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

    // MARK: - List Processing

    private func createListHTML(from items: [ListItem]) -> String {
        guard !items.isEmpty else { return "" }

        var htmlParts: [String] = []
        var currentLevel = -1
        var openLists: [(level: Int, type: ListType)] = []

        for item in items {
            // Close lists if we're going to a shallower level (not same level!)
            while currentLevel > item.level && !openLists.isEmpty {
                let closingList = openLists.removeLast()
                let tag = closingList.type == .bullet ? "ul" : "ol"
                htmlParts.append("</\(tag)>")
                currentLevel = openLists.last?.level ?? -1
            }

            // Open new lists if we're going deeper
            while currentLevel < item.level {
                currentLevel += 1
                let tag = item.type == .bullet ? "ul" : "ol"
                htmlParts.append("<\(tag)>")
                openLists.append((level: currentLevel, type: item.type))
            }

            // Add the list item
            htmlParts.append("<li>\(item.text)</li>")
        }

        // Close all remaining open lists
        while !openLists.isEmpty {
            let closingList = openLists.removeLast()
            let tag = closingList.type == .bullet ? "ul" : "ol"
            htmlParts.append("</\(tag)>")
        }

        return htmlParts.joined(separator: "\n")
    }

    // MARK: - Transformations

    private func applySpecialCharacters(to html: String) -> String {
        var result = html

        for special in config.specialCharacters where special.enabled {
            // Only wrap special characters that aren't already inside the wrap tag
            // This prevents double-wrapping when DOCX already has the formatting
            let wrappedPattern = "<\(special.wrapTag)>[\(NSRegularExpression.escapedPattern(for: special.character))]</\(special.wrapTag)>"

            // Check if character is already wrapped
            if result.range(of: wrappedPattern, options: .regularExpression) != nil {
                // Already wrapped, skip
                continue
            }

            // Apply replacement only to text content, not within HTML tags
            // This prevents corrupting URLs and attributes
            result = replaceInTextContent(
                in: result,
                search: special.character,
                replace: "<\(special.wrapTag)>\(special.character)</\(special.wrapTag)>",
                caseSensitive: true
            )
        }

        return result
    }

    private func applyReplacements(to html: String) -> String {
        var result = html

        for replacement in config.replacements {
            result = replaceInTextContent(
                in: result,
                search: replacement.search,
                replace: replacement.replace,
                caseSensitive: replacement.caseSensitive
            )
        }

        return result
    }

    /// Replace text only in HTML text content, not in tags or attributes
    /// Also handles text split across formatting tags like </u><u>
    /// IMPORTANT: Skips replacements inside <a> tags to prevent nested anchors
    private func replaceInTextContent(in html: String, search: String, replace: String, caseSensitive: Bool) -> String {
        var result = ""
        var currentSegment = ""
        var i = html.startIndex
        var insideAnchor = false  // Track if we're inside an <a> tag

        while i < html.endIndex {
            let char = html[i]

            if char == "<" {
                // Check if this is a structural tag (a, p, h1, etc.) or formatting tag (u, em, strong, etc.)
                let tagStartIndex = i
                var tagEndIndex = i

                // Find the end of this tag
                while tagEndIndex < html.endIndex && html[tagEndIndex] != ">" {
                    tagEndIndex = html.index(after: tagEndIndex)
                }

                if tagEndIndex < html.endIndex {
                    let tagContent = String(html[html.index(after: tagStartIndex)...tagEndIndex])
                    let tagName = tagContent.split(separator: " ").first?.replacingOccurrences(of: ">", with: "") ?? ""
                    let cleanTagName = tagName.replacingOccurrences(of: "/", with: "")

                    // Track anchor tags
                    if cleanTagName == "a" {
                        insideAnchor = true
                    } else if tagName == "/a" {
                        insideAnchor = false
                    }

                    // Formatting tags that we want to include in text processing
                    let formattingTags = Set(["u", "em", "strong", "sup", "sub", "b", "i"])

                    if formattingTags.contains(cleanTagName) {
                        // This is a formatting tag - include it in the current segment
                        currentSegment += String(html[tagStartIndex...tagEndIndex])
                        i = html.index(after: tagEndIndex)
                        continue
                    } else {
                        // This is a structural tag - process accumulated segment first
                        if !currentSegment.isEmpty {
                            // Only apply replacements if we're NOT inside an anchor tag
                            if insideAnchor {
                                result += currentSegment
                            } else {
                                result += replaceWithFormattingAwareness(
                                    in: currentSegment,
                                    search: search,
                                    replace: replace,
                                    caseSensitive: caseSensitive
                                )
                            }
                            currentSegment = ""
                        }

                        // Add the structural tag as-is
                        result += String(html[tagStartIndex...tagEndIndex])
                        i = html.index(after: tagEndIndex)
                        continue
                    }
                }
            }

            // Regular character - add to current segment
            currentSegment.append(char)
            i = html.index(after: i)
        }

        // Process any remaining segment
        if !currentSegment.isEmpty {
            // Only apply replacements if we're NOT inside an anchor tag
            if insideAnchor {
                result += currentSegment
            } else {
                result += replaceWithFormattingAwareness(
                    in: currentSegment,
                    search: search,
                    replace: replace,
                    caseSensitive: caseSensitive
                )
            }
        }

        return result
    }

    /// Replace with awareness of formatting tags like <u>text</u> or split <u>part1</u><u>part2</u>
    private func replaceWithFormattingAwareness(in text: String, search: String, replace: String, caseSensitive: Bool) -> String {
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]

        // Build pattern to match the search text potentially wrapped in <u> tags and split across them
        let escapedSearch = NSRegularExpression.escapedPattern(for: search)

        // Allow </u><u> between any characters in the search string
        var flexiblePattern = ""
        for char in escapedSearch {
            flexiblePattern += String(char)
            if char != "\\" {  // Don't add split pattern after escape characters
                flexiblePattern += "(?:</u><u>)?"
            }
        }

        // Wrap pattern to optionally match surrounding <u> tags
        let pattern = "(?:<u>)?(\(flexiblePattern))(?:</u>)?"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: replace
        )
    }

    // MARK: - Helper Methods

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
