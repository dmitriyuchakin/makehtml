import Foundation

@main
struct ValidationTest {
    static func main() {
        // Simple CLI test for validation
        print("=== makeHTML Validation Test ===\n")

        let testFile = "/Users/dmitriy/www/AA/docx-html/test-spacing.docx"
        let configFile = "/Users/dmitriy/www/AA/docx-html/makeHTML-Swift/config.json"

        guard FileManager.default.fileExists(atPath: testFile) else {
            print("Error: Test file not found: \(testFile)")
            exit(1)
        }

        guard FileManager.default.fileExists(atPath: configFile) else {
            print("Error: Config file not found: \(configFile)")
            exit(1)
        }

        do {
            // Load config
            let configData = try Data(contentsOf: URL(fileURLWithPath: configFile))
            let config = try JSONDecoder().decode(ConversionConfig.self, from: configData)

            // Create converter
            let converter = DocxConverter(config: config)

            // Test 1: Extract plain text
            print("Test 1: Extracting plain text from DOCX...")
            let plainText = try converter.extractPlainText(docxURL: URL(fileURLWithPath: testFile))
            print("  → Extracted \(plainText.count) characters")
            print("  → First 150 chars: \(String(plainText.prefix(150)))")
            print()

            // Test 2: Convert to HTML
            print("Test 2: Converting DOCX to HTML...")
            let html = try converter.convert(docxURL: URL(fileURLWithPath: testFile))
            print("  → Generated HTML with \(html.count) characters")
            print()

            // Test 3: Validate
            print("Test 3: Validating conversion...")
            let validation = try converter.validateConversion(docxURL: URL(fileURLWithPath: testFile), htmlOutput: html)

            if validation.isValid {
                print("  ✓ VALIDATION PASSED!")
                print("  → DOCX text (raw): \(validation.docxText.count) chars")
                print("  → HTML text (raw): \(validation.htmlText.count) chars")

                // Show normalized lengths
                let normalizedDocx = validation.docxText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
                let normalizedHTML = validation.htmlText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
                print("  → DOCX text (normalized): \(normalizedDocx.count) chars")
                print("  → HTML text (normalized): \(normalizedHTML.count) chars")
            } else {
                print("  ✗ VALIDATION FAILED!")
                print("  → Found \(validation.differences.count) difference(s)")
                print("  → DOCX text: \(validation.docxText.count) chars")
                print("  → HTML text: \(validation.htmlText.count) chars")
                print()
                print("First 5 differences:")
                for (i, diff) in validation.differences.prefix(5).enumerated() {
                    print("\n  Difference #\(i + 1):")
                    print("    Type: \(diff.type)")
                    print("    Position: \(diff.position)")
                    if let expected = diff.expected {
                        print("    Expected: \"\(expected.prefix(100))\"")
                    }
                    if let actual = diff.actual {
                        print("    Actual: \"\(actual.prefix(100))\"")
                    }
                }
            }

            print("\n=== Test Complete ===")

        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
}
