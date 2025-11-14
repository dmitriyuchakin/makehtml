import Foundation

@main
struct BatchValidationTest {
    static func main() {
        print("=== makeHTML Batch Validation Test ===\n")

        let testDocsDir = "/Users/dmitriy/www/AA/docx-html/test docs"
        let configFile = "/Users/dmitriy/Library/Application Support/makeHTML/config.json"

        guard FileManager.default.fileExists(atPath: configFile) else {
            print("Error: Config file not found: \(configFile)")
            exit(1)
        }

        // Get all DOCX files
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: testDocsDir) else {
            print("Error: Could not read test-docs directory")
            exit(1)
        }

        let docxFiles = files.filter { $0.hasSuffix(".docx") }.sorted()

        if docxFiles.isEmpty {
            print("No DOCX files found in test-docs")
            exit(1)
        }

        print("Found \(docxFiles.count) DOCX files to test\n")
        print(String(repeating: "=", count: 80))

        do {
            // Load config
            let configData = try Data(contentsOf: URL(fileURLWithPath: configFile))
            let config = try JSONDecoder().decode(ConversionConfig.self, from: configData)

            // Create converter
            let converter = DocxConverter(config: config)

            var passCount = 0
            var failCount = 0
            var errorCount = 0

            for (index, filename) in docxFiles.enumerated() {
                let filePath = "\(testDocsDir)/\(filename)"
                print("\n[\(index + 1)/\(docxFiles.count)] \(filename)")
                print(String(repeating: "-", count: 80))

                do {
                    // Extract plain text
                    let plainText = try converter.extractPlainText(docxURL: URL(fileURLWithPath: filePath))
                    print("  Plain text: \(plainText.count) chars")

                    // Convert to HTML
                    let html = try converter.convert(docxURL: URL(fileURLWithPath: filePath))
                    print("  HTML output: \(html.count) chars")

                    // Validate
                    let validation = try converter.validateConversion(docxURL: URL(fileURLWithPath: filePath), htmlOutput: html)

                    if validation.isValid {
                        print("  ✓ VALIDATION PASSED")

                        // Show normalized character counts
                        let normalizedDocx = validation.docxText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
                        let normalizedHTML = validation.htmlText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
                        print("  → Normalized: \(normalizedDocx.count) chars (DOCX) = \(normalizedHTML.count) chars (HTML)")

                        passCount += 1
                    } else {
                        print("  ✗ VALIDATION FAILED")
                        print("  → Found \(validation.differences.count) difference(s)")
                        print("  → DOCX: \(validation.docxText.count) chars, HTML: \(validation.htmlText.count) chars")

                        // Show first 3 differences
                        print("\n  First differences:")
                        for (i, diff) in validation.differences.prefix(3).enumerated() {
                            print("\n    #\(i + 1): \(diff.type) at position \(diff.position)")
                            if let expected = diff.expected {
                                let preview = expected.prefix(60)
                                print("      Expected: \"\(preview)\(expected.count > 60 ? "..." : "")\"")
                            }
                            if let actual = diff.actual {
                                let preview = actual.prefix(60)
                                print("      Actual:   \"\(preview)\(actual.count > 60 ? "..." : "")\"")
                            }
                        }

                        failCount += 1
                    }

                } catch {
                    print("  ✗ ERROR: \(error.localizedDescription)")
                    errorCount += 1
                }
            }

            // Summary
            print("\n" + String(repeating: "=", count: 80))
            print("\n=== SUMMARY ===")
            print("Total files: \(docxFiles.count)")
            print("  ✓ Passed: \(passCount)")
            print("  ✗ Failed: \(failCount)")
            print("  ⚠ Errors: \(errorCount)")
            print()

            if passCount == docxFiles.count {
                print("🎉 All tests passed!")
            } else if errorCount == 0 && failCount > 0 {
                print("⚠ Some validations failed - text differences detected")
            } else {
                print("⚠ Some files had conversion errors")
            }

        } catch {
            print("Error loading config: \(error)")
            exit(1)
        }
    }
}
