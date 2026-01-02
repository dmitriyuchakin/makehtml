import Foundation
import AppKit

/// Handles logging of conversion operations to daily log files
class ConversionLogger {

    // MARK: - Properties

    private let logsDirectory: URL
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    // MARK: - Initialization

    init() {
        // Set up logs directory in Application Support
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/makeHTML/logs")
        self.logsDirectory = appSupport

        // Create logs directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        // Date formatter for log file names (YYYY-MM-DD.log)
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Time formatter for log entries
        self.timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Clean up old logs (keep last 30 days)
        cleanupOldLogs()
    }

    // MARK: - Public Logging Methods

    func logConversionStart(sourceURL: URL, fileSize: Int64) {
        let header = """
        ================================================================================
        [\(timestamp())] CONVERSION START
        ================================================================================
        Source: \(sourceURL.path) (\(formatFileSize(fileSize)))
        App Version: 0.5 (Build 1111)
        macOS: \(getOSVersion()), Swift: 5.9
        Config: ~/Library/Application Support/makeHTML/config.json

        """
        appendToLog(header)
    }

    func logDocumentStructure(paragraphCount: Int, headingCount: Int, tableCount: Int, hyperlinkCount: Int, specialChars: [String: Int]) {
        var structure = "Document Structure:\n"
        structure += "  - \(paragraphCount) paragraphs (\(headingCount) headings, \(paragraphCount - headingCount) regular)\n"

        if tableCount > 0 {
            structure += "  - \(tableCount) table\(tableCount == 1 ? "" : "s")\n"
        }

        if hyperlinkCount > 0 {
            structure += "  - \(hyperlinkCount) hyperlink\(hyperlinkCount == 1 ? "" : "s")\n"
        }

        if !specialChars.isEmpty {
            let charList = specialChars.map { "\($0.value)× \($0.key) (U+\(unicodeHex($0.key)))" }.joined(separator: ", ")
            structure += "  - Special chars: \(charList)\n"
        }

        structure += "\n"
        appendToLog(structure)
    }

    func logStep(_ step: String, duration: TimeInterval? = nil) {
        var message = "[\(shortTime())] \(step)"
        if let duration = duration {
            message += " (\(Int(duration * 1000))ms)"
        }
        appendToLog(message + "\n")
    }

    func logConversionSuccess(htmlSize: Int, outputURL: URL) {
        let message = """

        ✓ Conversion successful (\(formatNumber(htmlSize)) chars HTML)
        Output: \(outputURL.path)

        """
        appendToLog(message)
    }

    func logValidationResults(_ validation: ValidationResult, docxText: String, htmlText: String) {
        var message = """
        --------------------------------------------------------------------------------
        VALIDATION RESULTS
        --------------------------------------------------------------------------------

        """

        if validation.isValid {
            let normalizedDocx = normalizeWhitespace(validation.docxText)
            let normalizedHTML = normalizeWhitespace(validation.htmlText)

            message += """
            ✓ VALIDATION PASSED

            Character Counts:
              DOCX plain text:              \(formatNumber(validation.docxText.count)) chars
              HTML plain text (raw):        \(formatNumber(validation.htmlText.count)) chars
              HTML plain text (normalized): \(formatNumber(normalizedHTML.count)) chars
              Expected (normalized):        \(formatNumber(normalizedDocx.count)) chars
              Match: Perfect ✓

            """
        } else {
            let normalizedDocx = normalizeWhitespace(validation.docxText)
            let normalizedHTML = normalizeWhitespace(validation.htmlText)
            let diff = normalizedDocx.count - normalizedHTML.count
            let diffSign = diff > 0 ? "-" : "+"

            message += """
            ⚠ VALIDATION WARNING: Found \(validation.differences.count) difference\(validation.differences.count == 1 ? "" : "s")

            Character Counts:
              DOCX plain text:              \(formatNumber(validation.docxText.count)) chars
              HTML plain text (raw):        \(formatNumber(validation.htmlText.count)) chars
              HTML plain text (normalized): \(formatNumber(normalizedHTML.count)) chars
              Expected (normalized):        \(formatNumber(normalizedDocx.count)) chars
              Difference:                   \(diffSign)\(abs(diff)) chars (\(abs(diff)) character\(abs(diff) == 1 ? "" : "s") \(diff > 0 ? "missing" : "extra"))

            """

            // Log each difference
            for (index, difference) in validation.differences.prefix(10).enumerated() {
                message += formatDifference(index + 1, difference, validation.docxText, validation.htmlText)
            }

            if validation.differences.count > 10 {
                message += "\n... and \(validation.differences.count - 10) more difference\(validation.differences.count - 10 == 1 ? "" : "s")\n"
            }
        }

        // Add text samples
        message += """
        --------------------------------------------------------------------------------
        SAMPLE TEXT (first 200 characters):
        --------------------------------------------------------------------------------
        DOCX: "\(validation.docxText.prefix(200))"

        HTML: "\(validation.htmlText.prefix(200))"

        """

        appendToLog(message)
    }

    func logConversionEnd(totalDuration: TimeInterval) {
        let message = """
        [\(shortTime())] Total conversion time: \(Int(totalDuration * 1000))ms
        ================================================================================

        """
        appendToLog(message)
    }

    func logError(_ error: Error, context: String = "") {
        var message = """

        ✗ ERROR: \(error.localizedDescription)

        ERROR DETAILS:
          Type: \(type(of: error))
          Message: \(error.localizedDescription)

        """

        if !context.isEmpty {
            message += "  Context: \(context)\n"
        }

        message += "\n"
        appendToLog(message)
    }

    // MARK: - Log File Access

    func getTodayLogURL() -> URL {
        let today = dateFormatter.string(from: Date())
        return logsDirectory.appendingPathComponent("\(today).log")
    }

    func openTodayLog() {
        let logURL = getTodayLogURL()
        NSWorkspace.shared.open(logURL)
    }

    // MARK: - Private Methods

    private func appendToLog(_ message: String) {
        let logURL = getTodayLogURL()

        guard let data = message.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logURL.path) {
            // Append to existing log
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // Create new log file
            try? data.write(to: logURL, options: .atomic)
        }
    }

    private func formatDifference(_ index: Int, _ diff: TextDifference, _ docxText: String, _ htmlText: String) -> String {
        var result = """

        DIFFERENCE #\(index) [Position \(formatNumber(diff.position)) of \(formatNumber(docxText.count))]:
          Type: \(diff.type.description.uppercased())

        """

        let contextRange = 40 // Characters to show before/after

        switch diff.type {
        case .missing:
            if let expected = diff.expected {
                let start = max(0, diff.position - contextRange)
                let end = min(docxText.count, diff.position + contextRange)
                let startIdx = docxText.index(docxText.startIndex, offsetBy: start)
                let endIdx = docxText.index(docxText.startIndex, offsetBy: end)
                let context = String(docxText[startIdx..<endIdx])

                result += """
                  Context in DOCX (chars \(start)-\(end)):
                    "\(context)"

                  Expected text: "\(expected.prefix(50))"
                  Actual text:   [MISSING]

                """

                // Try to identify what's missing
                if expected.count == 1, let char = expected.first {
                    result += "  Missing character: \(char) (U+\(unicodeHex(String(char))))\n"
                }
            }

        case .extra:
            if let actual = diff.actual {
                result += """
                  Actual text contains extra characters: "\(actual.prefix(50))"

                """
            }

        case .different:
            if let expected = diff.expected, let actual = diff.actual {
                result += """
                  Expected text: "\(expected.prefix(50))"
                  Actual text:   "\(actual.prefix(50))"

                """
            }
        }

        result += """
          Location Hints:
            → Search HTML for: "\(diff.actual?.prefix(30) ?? "[missing]")"
            → Search DOCX for: "\(diff.expected?.prefix(30) ?? "[extra]")"

        """

        return result
    }

    private func cleanupOldLogs() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        for file in files where file.pathExtension == "log" {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Formatters

    private func timestamp() -> String {
        return timeFormatter.string(from: Date())
    }

    private func shortTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.0f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    private func unicodeHex(_ char: String) -> String {
        guard let scalar = char.unicodeScalars.first else { return "????" }
        return String(format: "%04X", scalar.value)
    }

    private func getOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func normalizeWhitespace(_ text: String) -> String {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - DifferenceType Extension

extension DifferenceType: CustomStringConvertible {
    var description: String {
        switch self {
        case .missing: return "missing"
        case .extra: return "extra"
        case .different: return "different"
        }
    }
}
