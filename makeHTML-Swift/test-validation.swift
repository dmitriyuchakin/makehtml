#!/usr/bin/env swift

import Foundation

// Simple test to verify validation functions work
// This will test the extractPlainText functionality

let testDocxPath = "/Users/dmitriy/www/AA/docx-html/test-spacing.docx"

guard FileManager.default.fileExists(atPath: testDocxPath) else {
    print("Error: test-spacing.docx not found")
    exit(1)
}

do {
    // Load config
    let configPath = "/Users/dmitriy/www/AA/docx-html/config.json"
    let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))

    // Initialize converter
    let converter = DocxConverter(config: try JSONDecoder().decode(ConversionConfig.self, from: configData))

    // Test 1: Extract plain text
    print("=== Test 1: Extract Plain Text ===")
    let plainText = try converter.extractPlainText(docxURL: URL(fileURLWithPath: testDocxPath))
    print("Plain text length: \(plainText.count) characters")
    print("First 200 characters:")
    print(String(plainText.prefix(200)))
    print()

    // Test 2: Convert to HTML
    print("=== Test 2: Convert to HTML ===")
    let htmlOutput = try converter.convert(docxURL: URL(fileURLWithPath: testDocxPath))
    print("HTML length: \(htmlOutput.count) characters")
    print("First 200 characters:")
    print(String(htmlOutput.prefix(200)))
    print()

    // Test 3: Validate conversion
    print("=== Test 3: Validate Conversion ===")
    let validation = try converter.validateConversion(docxURL: URL(fileURLWithPath: testDocxPath), htmlOutput: htmlOutput)

    if validation.isValid {
        print("✓ VALIDATION PASSED: Text matches perfectly!")
    } else {
        print("✗ VALIDATION FAILED: Found \(validation.differences.count) difference(s)")
        for (index, diff) in validation.differences.prefix(5).enumerated() {
            print("\nDifference #\(index + 1):")
            print("  Type: \(diff.type)")
            print("  Position: \(diff.position)")
            if let expected = diff.expected {
                print("  Expected: \"\(expected)\"")
            }
            if let actual = diff.actual {
                print("  Actual: \"\(actual)\"")
            }
        }
    }

    print("\n=== Summary ===")
    print("DOCX plain text: \(validation.docxText.count) characters")
    print("HTML plain text: \(validation.htmlText.count) characters")

} catch {
    print("Error: \(error)")
    exit(1)
}
