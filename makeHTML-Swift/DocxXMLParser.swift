import Foundation

// MARK: - Data Models

/// Represents a text run within a paragraph
struct DocxRun {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let isUnderline: Bool
    let isSuperscript: Bool
    let isSubscript: Bool
}

/// Represents a hyperlink within a paragraph
struct DocxHyperlink {
    let url: String
    let text: String
}

/// Represents content within a paragraph (either a run, hyperlink, or line break)
enum DocxParagraphContent {
    case run(DocxRun)
    case hyperlink(DocxHyperlink)
    case lineBreak
}

/// Represents a paragraph in the document
struct DocxParagraph {
    let contents: [DocxParagraphContent]
    let isHeading: Bool
    let listLevel: Int?
    let listType: String? // "bullet" or "numbered"
}

/// Represents a table cell
struct DocxTableCell {
    let text: String
}

/// Represents a table row
struct DocxTableRow {
    let cells: [DocxTableCell]
}

/// Represents a table
struct DocxTable {
    let rows: [DocxTableRow]
}

/// Represents a body element (paragraph or table)
enum DocxBodyElement {
    case paragraph(DocxParagraph)
    case table(DocxTable)
}

/// Parsed document structure
struct DocxDocument {
    let elements: [DocxBodyElement]
    let relationships: [String: String] // Relationship ID -> URL mapping
}

// MARK: - XML Parser

/// SAX-style parser for DOCX document.xml that preserves ALL whitespace
class DocxXMLParser: NSObject, XMLParserDelegate {
    private var elements: [DocxBodyElement] = []
    private var relationships: [String: String] = [:]

    // Replacement search terms for conflict detection
    private var replacementSearchTerms: Set<String> = []

    // Current parsing state
    private var currentPath: [String] = []
    private var currentParagraph: DocxParagraph?
    private var paragraphContents: [DocxParagraphContent] = []
    private var currentRun: DocxRun?
    private var runText: String = ""
    private var runFormatting: RunFormatting = RunFormatting()
    private var currentHyperlink: DocxHyperlink?
    private var hyperlinkText: String = ""
    private var hyperlinkRelId: String?

    // Field-based hyperlink state (for HYPERLINK field codes)
    private var inFieldHyperlink: Bool = false
    private var fieldHyperlinkURL: String?
    private var fieldHyperlinkText: String = ""
    private var fieldInstrText: String = ""  // Accumulates instrText content
    private var collectingFieldText: Bool = false

    private var isHeading: Bool = false
    private var listLevel: Int?
    private var listType: String?

    // Table parsing state
    private var currentTable: DocxTable?
    private var tableRows: [DocxTableRow] = []
    private var currentTableRow: DocxTableRow?
    private var rowCells: [DocxTableCell] = []
    private var currentTableCell: DocxTableCell?
    private var cellText: String = ""

    // Helper for tracking formatting
    private struct RunFormatting {
        var isBold = false
        var isItalic = false
        var isUnderline = false
        var isSuperscript = false
        var isSubscript = false
    }

    // MARK: - Public Interface

    func parse(documentData: Data, relationships: [String: String], replacementSearchTerms: Set<String> = []) throws -> DocxDocument {
        self.relationships = relationships
        self.replacementSearchTerms = replacementSearchTerms
        self.elements = []

        let parser = XMLParser(data: documentData)
        parser.delegate = self

        guard parser.parse() else {
            if let error = parser.parserError {
                throw error
            }
            throw NSError(domain: "DocxXMLParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML"])
        }

        return DocxDocument(elements: elements, relationships: relationships)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        currentPath.append(localName)

        switch localName {
        case "p": // Paragraph start
            paragraphContents = []
            isHeading = false
            listLevel = nil
            listType = nil

        case "pStyle": // Paragraph style (for heading detection)
            if let val = attributeDict["w:val"] ?? attributeDict["val"] {
                isHeading = val.lowercased().contains("heading")
            }

        case "numPr": // List numbering properties
            // Will be followed by ilvl and numId elements
            break

        case "ilvl": // List level
            if let val = attributeDict["w:val"] ?? attributeDict["val"],
               let level = Int(val) {
                listLevel = level
            }

        case "numId": // List number ID (could be used to determine bullet vs numbered)
            if let val = attributeDict["w:val"] ?? attributeDict["val"] {
                // Simple heuristic: low IDs are often bullets, higher are numbered
                // This is simplified; real implementation would need numbering.xml
                listType = Int(val) ?? 0 < 10 ? "bullet" : "numbered"
            }

        case "r": // Run start
            runText = ""
            runFormatting = RunFormatting()

        case "br": // Line break
            // Add a line break to the paragraph contents
            if !inTableCell() && !inHyperlink() {
                paragraphContents.append(.lineBreak)
            }

        case "b", "bCs": // Bold
            runFormatting.isBold = true

        case "i", "iCs": // Italic
            runFormatting.isItalic = true

        case "u": // Underline
            runFormatting.isUnderline = true

        case "vertAlign": // Superscript/subscript
            if let val = attributeDict["w:val"] ?? attributeDict["val"] {
                if val == "superscript" {
                    runFormatting.isSuperscript = true
                } else if val == "subscript" {
                    runFormatting.isSubscript = true
                }
            }

        case "hyperlink": // Hyperlink start
            hyperlinkText = ""
            hyperlinkRelId = attributeDict["r:id"] ?? attributeDict["id"]

        case "fldChar": // Field character (for HYPERLINK field codes)
            if let fldCharType = attributeDict["w:fldCharType"] ?? attributeDict["fldCharType"] {
                if fldCharType == "begin" {
                    // Start of a field
                    inFieldHyperlink = false
                    fieldHyperlinkURL = nil
                    fieldHyperlinkText = ""
                    fieldInstrText = ""
                    collectingFieldText = false
                } else if fldCharType == "separate" {
                    // Separator between field instruction and field result
                    // Now process the accumulated instrText
                    if fieldInstrText.contains("HYPERLINK") {
                        // XMLParser automatically decodes entities, so &quot; becomes "
                        if let urlMatch = fieldInstrText.range(of: #""([^"]+)""#, options: .regularExpression) {
                            let urlWithQuotes = String(fieldInstrText[urlMatch])
                            fieldHyperlinkURL = urlWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            inFieldHyperlink = true
                        }
                    }
                    // After this, text nodes contain the displayed text
                    collectingFieldText = inFieldHyperlink
                } else if fldCharType == "end" {
                    // End of field
                    if inFieldHyperlink, let url = fieldHyperlinkURL, !fieldHyperlinkText.isEmpty {
                        // Check if field hyperlink text matches any replacement search term
                        let matchesReplacement = replacementSearchTerms.contains { searchTerm in
                            fieldHyperlinkText.range(of: searchTerm, options: .caseInsensitive) != nil
                        }

                        if matchesReplacement {
                            // Convert to plain text run
                            let run = DocxRun(text: fieldHyperlinkText, isBold: false, isItalic: false,
                                             isUnderline: false, isSuperscript: false, isSubscript: false)
                            paragraphContents.append(.run(run))
                        } else {
                            // Create hyperlink from field
                            let hyperlink = DocxHyperlink(url: url, text: fieldHyperlinkText)
                            paragraphContents.append(.hyperlink(hyperlink))
                        }
                    }
                    inFieldHyperlink = false
                    fieldHyperlinkURL = nil
                    fieldHyperlinkText = ""
                    fieldInstrText = ""
                    collectingFieldText = false
                }
            }

        case "tbl": // Table start
            tableRows = []

        case "tr": // Table row start
            rowCells = []

        case "tc": // Table cell start
            cellText = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let localName = currentPath.last ?? ""

        // Handle instrText for field-based hyperlinks
        if localName == "instrText" {
            // Accumulate instrText content (XMLParser may call this multiple times)
            fieldInstrText += string
        }

        // Only capture text within <w:t> elements
        if localName == "t" {
            if collectingFieldText {
                // Collecting text for field-based hyperlink
                fieldHyperlinkText += string
                NSLog("[makeHTML] Collecting field text: '\(string)' (total: '\(fieldHyperlinkText)')")
            } else if inTableCell() {
                cellText += string
            } else if inHyperlink() {
                hyperlinkText += string
            } else if inRun() {
                // This is the key: XMLParser preserves ALL characters, including whitespace
                runText += string
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName

        switch localName {
        case "r": // Run end
            if collectingFieldText {
                // This run is part of a field-based hyperlink, skip it (already collected)
            } else if inHyperlink() {
                // This run is part of a hyperlink, skip it (will be handled by hyperlink end)
            } else if inTableCell() {
                // Table cell text handling
            } else {
                // Regular run in paragraph
                let run = DocxRun(
                    text: runText,
                    isBold: runFormatting.isBold,
                    isItalic: runFormatting.isItalic,
                    isUnderline: runFormatting.isUnderline,
                    isSuperscript: runFormatting.isSuperscript,
                    isSubscript: runFormatting.isSubscript
                )
                paragraphContents.append(.run(run))
            }
            runText = ""

        case "hyperlink": // Hyperlink end
            if let relId = hyperlinkRelId, let url = relationships[relId] {
                // Check if hyperlink text matches any replacement search term
                let matchesReplacement = replacementSearchTerms.contains { searchTerm in
                    hyperlinkText.range(of: searchTerm, options: .caseInsensitive) != nil
                }

                if matchesReplacement {
                    // Convert to plain text run - let config handle linking
                    let run = DocxRun(text: hyperlinkText, isBold: false, isItalic: false,
                                     isUnderline: false, isSuperscript: false, isSubscript: false)
                    paragraphContents.append(.run(run))
                } else {
                    // Keep as hyperlink - no conflict
                    let hyperlink = DocxHyperlink(url: url, text: hyperlinkText)
                    paragraphContents.append(.hyperlink(hyperlink))
                }
            }
            hyperlinkText = ""
            hyperlinkRelId = nil

        case "p": // Paragraph end
            // Only add non-empty paragraphs (unless they're list items)
            let hasContent = !paragraphContents.isEmpty
            let trimmedText = paragraphContents.compactMap {
                switch $0 {
                case .run(let run): return run.text
                case .hyperlink(let link): return link.text
                case .lineBreak: return nil
                }
            }.joined().trimmingCharacters(in: .whitespacesAndNewlines)

            if hasContent && (!trimmedText.isEmpty || listLevel != nil) {
                let paragraph = DocxParagraph(
                    contents: paragraphContents,
                    isHeading: isHeading,
                    listLevel: listLevel,
                    listType: listType
                )
                elements.append(.paragraph(paragraph))
            }

        case "tc": // Table cell end
            let cell = DocxTableCell(text: cellText)
            rowCells.append(cell)
            cellText = ""

        case "tr": // Table row end
            let row = DocxTableRow(cells: rowCells)
            tableRows.append(row)
            rowCells = []

        case "tbl": // Table end
            let table = DocxTable(rows: tableRows)
            elements.append(.table(table))
            tableRows = []

        default:
            break
        }

        currentPath.removeLast()
    }

    // MARK: - Helper Methods

    private func inRun() -> Bool {
        return currentPath.contains("r") && !inHyperlink()
    }

    private func inHyperlink() -> Bool {
        return currentPath.contains("hyperlink")
    }

    private func inTableCell() -> Bool {
        return currentPath.contains("tc")
    }
}
