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

enum ReplacementMode: String, Codable {
    case aggressive  // Config replacements override DOCX hyperlinks
    case safe        // Preserve DOCX hyperlinks, don't strip them
}

struct ConversionConfig: Codable {
    let output: OutputConfig
    let replacements: [Replacement]
    let replacementsMode: ReplacementMode
    let quoteDetection: QuoteDetection
    let linkHandling: LinkHandling
    let codeSnippets: [ConfigCodeSnippet]
    let headingDetection: HeadingDetection?  // Optional for backward compatibility
    let tidyFormatting: TidyFormatting?  // Optional for backward compatibility

    enum CodingKeys: String, CodingKey {
        case output
        case replacements
        case replacementsMode = "replacements_mode"
        case quoteDetection = "quote_detection"
        case linkHandling = "link_handling"
        case codeSnippets = "code_snippets"
        case headingDetection = "heading_detection"
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

struct Replacement: Codable {
    let search: String
    let replace: String?
    let wrapTag: String?
    let caseSensitive: Bool?
    let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case search
        case replace
        case wrapTag = "wrap_tag"
        case caseSensitive = "case_sensitive"
        case enabled
    }
}

struct QuoteDetection: Codable {
    let enabled: Bool
    let threshold: Int
    let wrapOpen: String
    let wrapClose: String
    let quoteTypes: [String]

    enum CodingKeys: String, CodingKey {
        case enabled
        case threshold
        case wrapOpen = "wrap_open"
        case wrapClose = "wrap_close"
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

struct HeadingDetection: Codable {
    let enabled: Bool
    let maxLength: Int

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxLength = "max_length"
    }
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

        // Build set of replacement search terms to detect conflicts
        // Only in aggressive mode - safe mode preserves all DOCX hyperlinks
        let replacementSearchTerms: Set<String>
        if config.replacementsMode == .aggressive {
            replacementSearchTerms = Set(
                config.replacements
                    .filter { $0.enabled ?? true }
                    .map { $0.search }
            )
        } else {
            replacementSearchTerms = []
        }

        // Parse document using XMLParser (preserves whitespace!)
        let parser = DocxXMLParser()
        return try parser.parse(
            documentData: documentData,
            relationships: relationships,
            replacementSearchTerms: replacementSearchTerms
        )
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

        // Apply transformations (unified replacements)
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
            case .lineBreak:
                texts.append(" ")
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
        // If heading detection is enabled and paragraph contains line breaks, split it
        if let headingDetection = config.headingDetection, headingDetection.enabled,
           paragraph.contents.contains(where: { if case .lineBreak = $0 { return true } else { return false } }) {
            return renderParagraphWithLineBreaks(paragraph)
        }

        let content = renderParagraphContents(paragraph.contents)

        // Skip empty paragraphs
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        // Determine if this should be a heading (using heuristic detection if enabled)
        let isHeading = shouldTreatAsHeading(paragraph, content: content)
        let tag = isHeading ? config.output.headingTag : config.output.paragraphTag

        // Check for quote detection (only for non-headings)
        if !isHeading && config.quoteDetection.enabled {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if shouldWrapAsQuote(trimmed) {
                // Use the full wrapper HTML with content directly inside
                return "\(config.quoteDetection.wrapOpen)\(content)\(config.quoteDetection.wrapClose)"
            }
        }

        // Strip formatting tags from headings
        let finalContent = isHeading ? stripHTMLTags(content) : content
        return "<\(tag)>\(finalContent)</\(tag)>"
    }

    private func renderParagraphWithLineBreaks(_ paragraph: DocxParagraph) -> String {
        var segments: [[DocxParagraphContent]] = []
        var currentSegment: [DocxParagraphContent] = []

        // Split contents at line breaks
        for content in paragraph.contents {
            if case .lineBreak = content {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                    currentSegment = []
                }
            } else {
                currentSegment.append(content)
            }
        }

        // Add the last segment
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        // Render each segment as either heading or paragraph
        var results: [String] = []
        for segment in segments {
            let segmentHTML = renderParagraphContents(segment)
            guard !segmentHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            // Check if this segment should be a heading based on length
            let plainText = stripHTMLTags(segmentHTML).trimmingCharacters(in: .whitespacesAndNewlines)
            let isHeading = !plainText.isEmpty && plainText.count <= (config.headingDetection?.maxLength ?? 50)

            if isHeading {
                let strippedContent = stripHTMLTags(segmentHTML)
                results.append("<\(config.output.headingTag)>\(strippedContent)</\(config.output.headingTag)>")
            } else {
                results.append("<\(config.output.paragraphTag)>\(segmentHTML)</\(config.output.paragraphTag)>")
            }
        }

        return results.joined(separator: "\n\n")
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
            case .lineBreak:
                // Line breaks are handled at paragraph level when heading detection is enabled
                // If we encounter one here, it means heading detection is disabled, so render as <br>
                result.append("<br>")
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

            case .lineBreak:
                // Save any pending run first
                if let current = currentRun {
                    merged.append(.run(current))
                    currentRun = nil
                }
                // Add the line break
                merged.append(.lineBreak)
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

    /// Wrap text in HTML tags with duplicate prevention
    private func wrapText(_ html: String, search: String, wrapTag: String, caseSensitive: Bool) -> String {
        var result = html
        let openTag = "<\(wrapTag)>"
        let closeTag = "</\(wrapTag)>"
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var searchStart = result.startIndex

        while searchStart < result.endIndex {
            guard let range = result.range(of: search, options: options, range: searchStart..<result.endIndex) else {
                break
            }

            // Check if this instance is already wrapped
            var isWrapped = false
            if result.distance(from: result.startIndex, to: range.lowerBound) >= openTag.count {
                let beforeRange = result.index(range.lowerBound, offsetBy: -openTag.count)..<range.lowerBound
                if result[beforeRange] == openTag[...] {
                    let afterStart = range.upperBound
                    if result.distance(from: afterStart, to: result.endIndex) >= closeTag.count {
                        let afterRange = afterStart..<result.index(afterStart, offsetBy: closeTag.count)
                        if result[afterRange] == closeTag[...] {
                            isWrapped = true
                        }
                    }
                }
            }

            if !isWrapped {
                // Wrap this instance
                let replacement = "\(openTag)\(result[range])\(closeTag)"
                result.replaceSubrange(range, with: replacement)
                searchStart = result.index(range.lowerBound, offsetBy: replacement.count)
            } else {
                searchStart = range.upperBound
            }
        }

        return result
    }

    // MARK: - Text Replacements (Unified)
    // Handles both:
    // 1. Wrapping text in tags (wrap_tag mode)
    // 2. Replacing text with custom HTML (replace mode)
    private func applyReplacements(to html: String) -> String {
        var result = html

        for replacement in config.replacements where replacement.enabled ?? true {
            // Validate: must have either replace OR wrapTag (not both)
            guard (replacement.replace != nil) != (replacement.wrapTag != nil) else {
                continue // Skip invalid config
            }

            if let wrapTag = replacement.wrapTag {
                // WRAPPING MODE (old special_characters behavior)
                result = wrapText(result,
                                search: replacement.search,
                                wrapTag: wrapTag,
                                caseSensitive: replacement.caseSensitive ?? false)
            } else if let replaceWith = replacement.replace {
                // REPLACEMENT MODE (existing behavior)
                let caseSensitive = replacement.caseSensitive ?? true

                // For single-character replacements (like nbsp), use simple replacement
                // to avoid issues with regex patterns and formatting tag handling
                if replacement.search.count == 1 {
                    let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
                    result = result.replacingOccurrences(
                        of: replacement.search,
                        with: replaceWith,
                        options: options
                    )
                } else {
                    result = replaceInTextContent(
                        in: result,
                        search: replacement.search,
                        replace: replaceWith,
                        caseSensitive: caseSensitive,
                        wrapTag: nil
                    )
                }
            }
        }

        return result
    }

    /// Replace text only in HTML text content, not in tags or attributes
    /// Also handles text split across formatting tags like </u><u>
    /// IMPORTANT: Skips replacements inside <a> tags to prevent nested anchors in safe mode
    /// - Parameter wrapTag: If provided, skips instances already wrapped in this tag
    private func replaceInTextContent(in html: String, search: String, replace: String, caseSensitive: Bool, wrapTag: String? = nil) -> String {
        // In safe mode, use anchor-aware replacement to prevent nesting
        if config.replacementsMode == .safe && replace.contains("<a") {
            return replaceInTextContentSkippingAnchors(in: html, search: search, replace: replace, caseSensitive: caseSensitive, wrapTag: wrapTag)
        }

        // In aggressive mode or non-anchor replacements, use simple approach
        return replaceWithFormattingAwareness(in: html, search: search, replace: replace, caseSensitive: caseSensitive, wrapTag: wrapTag)
    }

    /// Segment-based approach with anchor tracking
    /// Used in safe mode to prevent nested anchors by skipping replacements inside existing <a> tags
    private func replaceInTextContentSkippingAnchors(in html: String, search: String, replace: String, caseSensitive: Bool, wrapTag: String? = nil) -> String {
        // Simple approach: just check if the replacement HTML contains <a> tag
        // If so, skip replacements inside existing <a> tags to prevent nesting
        let replacementContainsAnchor = replace.contains("<a")

        // If replacement doesn't create anchors, no need to check for nesting
        if !replacementContainsAnchor {
            // Just do the replacement on the whole HTML - simpler and faster
            return replaceWithFormattingAwareness(in: html, search: search, replace: replace, caseSensitive: caseSensitive, wrapTag: wrapTag)
        }

        // Otherwise, use the segment-based approach to avoid nesting anchors
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
                                    caseSensitive: caseSensitive,
                                    wrapTag: wrapTag
                                )
                            }
                            currentSegment = ""
                        }

                        // Track closing anchor tags AFTER processing segment
                        // This ensures content inside anchor is processed with insideAnchor=true
                        if tagName == "/a" {
                            insideAnchor = false
                        }

                        // Track opening anchor tags
                        if cleanTagName == "a" {
                            insideAnchor = true
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
                    caseSensitive: caseSensitive,
                    wrapTag: wrapTag
                )
            }
        }

        return result
    }

    /// Replace with awareness of formatting tags like <u>text</u> or split <u>part1</u><u>part2</u>
    /// - Parameter wrapTag: If provided, skips instances already wrapped in this tag
    private func replaceWithFormattingAwareness(in text: String, search: String, replace: String, caseSensitive: Bool, wrapTag: String? = nil) -> String {
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]

        // If wrapTag is provided, skip instances already wrapped in that tag
        if let wrapTag = wrapTag {
            // Manually iterate and replace only unwrapped instances
            var result = text
            let openTag = "<\(wrapTag)>"
            let closeTag = "</\(wrapTag)>"
            let searchOptions: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]

            var searchStart = result.startIndex

            while searchStart < result.endIndex {
                // Find next occurrence of search string
                guard let range = result.range(of: search, options: searchOptions, range: searchStart..<result.endIndex) else {
                    break
                }

                // Check if this instance is already wrapped
                var isWrapped = false

                // Check if there's an opening tag immediately before
                if result.distance(from: result.startIndex, to: range.lowerBound) >= openTag.count {
                    let beforeRange = result.index(range.lowerBound, offsetBy: -openTag.count)..<range.lowerBound
                    if result[beforeRange] == openTag[...] {
                        // Check if there's a closing tag immediately after
                        let afterStart = range.upperBound
                        if result.distance(from: afterStart, to: result.endIndex) >= closeTag.count {
                            let afterRange = afterStart..<result.index(afterStart, offsetBy: closeTag.count)
                            if result[afterRange] == closeTag[...] {
                                isWrapped = true
                            }
                        }
                    }
                }

                if !isWrapped {
                    // Replace this instance
                    result.replaceSubrange(range, with: replace)
                    // Move search start to after the replacement
                    searchStart = result.index(range.lowerBound, offsetBy: replace.count)
                } else {
                    // Skip this wrapped instance
                    searchStart = range.upperBound
                }
            }

            return result
        }

        // Build pattern to match the search text potentially wrapped in <u> tags and split across them
        // Iterate through original search string characters, escape each one, then add optional split
        var flexiblePattern = ""
        for char in search {
            let escapedChar = NSRegularExpression.escapedPattern(for: String(char))
            flexiblePattern += escapedChar
            flexiblePattern += "(?:</u><u>)?"
        }

        // Wrap pattern to optionally match surrounding <u> tags
        // Use negative lookbehind (?<!<[^>]*) to avoid matching inside HTML tags
        // However, Swift NSRegularExpression doesn't support variable-length lookbehind
        // So we'll use a simpler approach: match text that's not inside quotes
        let pattern = "(?:<u>)?(\(flexiblePattern))(?:</u>)?"

        // Simple check: if the match is inside a tag (between < and >), skip it
        // We'll do this in post-processing of matches

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        // Process matches in reverse order to avoid index shifting
        var result = text
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }

            // Check if this match is inside an HTML tag (between < and >)
            let beforeMatch = String(result[..<matchRange.lowerBound])
            let lastOpenBracket = beforeMatch.lastIndex(of: "<")
            let lastCloseBracket = beforeMatch.lastIndex(of: ">")

            // If there's an unclosed < before this match, it's inside a tag - skip it
            if let openPos = lastOpenBracket {
                if lastCloseBracket == nil || openPos > lastCloseBracket! {
                    continue  // Skip this match - it's inside a tag
                }
            }

            // This match is in text content, safe to replace
            result.replaceSubrange(matchRange, with: replace)
        }

        return result
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

// MARK: - Heading Detection (Modular Feature)
// This extension can be easily removed if the feature is no longer needed

extension DocxConverter {
    /// Determines if a paragraph should be treated as a heading based on heuristics
    /// - Parameters:
    ///   - paragraph: The paragraph to check
    ///   - content: The rendered text content of the paragraph
    /// - Returns: True if the paragraph should be treated as a heading
    func shouldTreatAsHeading(_ paragraph: DocxParagraph, content: String) -> Bool {
        // If heading detection is disabled or not configured, return false
        guard let headingDetection = config.headingDetection,
              headingDetection.enabled else {
            return false
        }

        // If paragraph is already marked as a heading, keep it
        if paragraph.isHeading {
            return true
        }

        // Get the plain text without HTML tags
        let plainText = stripHTMLTags(content).trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty paragraphs
        guard !plainText.isEmpty else {
            return false
        }

        // Simple rule: if the entire paragraph is under max_length, treat it as a heading
        return plainText.count <= headingDetection.maxLength
    }

    /// Strips HTML tags from a string
    private func stripHTMLTags(_ html: String) -> String {
        var result = html

        // Remove all HTML tags
        let tagPattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // Decode common HTML entities
        result = result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")

        return result
    }
}
