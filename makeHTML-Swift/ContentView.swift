import SwiftUI
import WebKit
import UniformTypeIdentifiers

// Code snippet model
struct CodeSnippet: Codable, Identifiable {
    var id: String { name }
    let name: String
    let file: String?  // Path to HTML file
    let code: String?  // Inline code (legacy support)
    var enabled: Bool
}

// Config model to parse JSON
struct Config: Codable {
    var code_snippets: [CodeSnippet]?
}

// WebKit wrapper for SwiftUI
struct HTMLPreviewView: NSViewRepresentable {
    let html: String
    let css: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                \(css)
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}

struct ContentView: View {
    @State private var isTargeted = false
    @State private var statusMessage = "Drop a .docx file here to convert"
    @State private var lastConvertedFile: URL?
    @State private var htmlContent: String?
    @State private var cssContent: String = ""
    @State private var isProcessing = false
    @State private var codeSnippets: [CodeSnippet] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with adaptive logo
                VStack(spacing: 8) {
                    if let lightImage = NSImage(named: "header-icon-light-600"),
                       let darkImage = NSImage(named: "header-icon-dark-600") {
                        Image(nsImage: NSApp.effectiveAppearance.name == .darkAqua ? darkImage : lightImage)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(height: 80)
                    } else {
                        // Fallback if images not found
                        Text("makeHTML")
                            .font(.system(size: 48, weight: .bold))
                    }
                }
                .padding(.top, 40)

            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isTargeted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [10])
                            )
                            .foregroundColor(isTargeted ? .blue : .gray.opacity(0.3))
                    )

                VStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 8)
                    }

                    Text(statusMessage)
                        .font(.headline)
                        .foregroundColor(isTargeted ? .blue : .primary)

                    if let htmlContent = htmlContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("HTML Preview:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: openHTMLInVSCode) {
                                    Label("Open HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)

                                Button(action: reloadPreview) {
                                    Label("Reload", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 8)

                            HTMLPreviewView(html: htmlContent, css: cssContent)
                                .frame(height: 300)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(40)
            }
            .frame(minHeight: htmlContent != nil ? 500 : 300)
            .padding(.horizontal, 40)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            Divider()
                .padding(.horizontal, 40)

            // Config Buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration")
                    .font(.headline)

                Text("~/Library/Application Support/makeHTML/")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: openConfigFolder) {
                        Label("Open Config Folder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button(action: editConfig) {
                        Label("Edit config.json", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            // Code Snippets Section
            if !codeSnippets.isEmpty {
                Divider()
                    .padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Code to HTML")
                        .font(.headline)

                    Text("Check snippets to append to generated HTML")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach($codeSnippets) { $snippet in
                            Toggle((snippet.name), isOn: $snippet.enabled)
                                .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
            }

                Spacer()
                    .frame(height: 20)
            }
        }
        .frame(minWidth: 700, minHeight: 720)
        .onAppear {
            loadStylesheet()
            loadCodeSnippets()
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "docx" else {
                DispatchQueue.main.async {
                    self.statusMessage = "Please drop a .docx file"
                }
                return
            }

            DispatchQueue.main.async {
                self.convertFile(url: url)
            }
        }
    }

    func convertFile(url: URL) {
        isProcessing = true
        statusMessage = "Converting \(url.lastPathComponent)..."
        htmlContent = nil

        let outputURL = url.deletingPathExtension().appendingPathExtension("html")

        // Get path to bundled converter
        guard let converterPath = Bundle.main.path(forResource: "makehtml", ofType: nil) else {
            statusMessage = "Error: Converter not found in bundle"
            isProcessing = false
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: converterPath)
        process.arguments = [url.path, "-o", outputURL.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // Success - read the HTML
                if let htmlString = try? String(contentsOf: outputURL, encoding: .utf8) {
                    // Append code snippets if any are enabled
                    let finalHTML = self.appendCodeSnippets(to: htmlString)

                    // Save the modified HTML back to file
                    try? finalHTML.write(to: outputURL, atomically: true, encoding: .utf8)

                    DispatchQueue.main.async {
                        self.statusMessage = "✓ Converted successfully: \(outputURL.lastPathComponent)"
                        self.htmlContent = finalHTML
                        self.lastConvertedFile = outputURL
                        self.isProcessing = false
                    }
                }
            } else {
                // Error
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    self.statusMessage = "✗ Error: \(errorMessage)"
                    self.isProcessing = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.statusMessage = "✗ Error: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }

    func openHTMLInVSCode() {
        guard let fileURL = lastConvertedFile else {
            return
        }
        openInEditor(url: fileURL)
    }

    func reloadPreview() {
        loadStylesheet()
        // Trigger view update by reassigning
        if let html = htmlContent {
            htmlContent = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                htmlContent = html
            }
        }
    }

    func loadStylesheet() {
        let styleURL = getStylesheetURL()

        // Create default stylesheet if it doesn't exist
        if !FileManager.default.fileExists(atPath: styleURL.path) {
            createDefaultStylesheet(at: styleURL)
        }

        // Load the stylesheet
        if let css = try? String(contentsOf: styleURL, encoding: .utf8) {
            cssContent = css
        }
    }

    func loadCodeSnippets() {
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/makeHTML/config.json")

        // Create default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configFile.path) {
            createDefaultConfig(at: configFile)
        }

        // Load and parse the config
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(Config.self, from: data),
              let snippets = config.code_snippets else {
            return
        }

        codeSnippets = snippets

        // Resize window to fit all content after snippets are loaded
        DispatchQueue.main.async {
            self.resizeWindowToFitContent()
        }
    }

    func resizeWindowToFitContent() {
        // Calculate needed height based on content
        let baseHeight: CGFloat = 580  // Header + drop zone + config section + padding
        let snippetSectionHeight: CGFloat = codeSnippets.isEmpty ? 0 : 140  // Section header + caption + divider
        let snippetItemHeight: CGFloat = 24  // Height per checkbox item
        let snippetItemsHeight = CGFloat(codeSnippets.count) * snippetItemHeight

        let totalHeight = baseHeight + snippetSectionHeight + snippetItemsHeight

        // Get the current window and resize it
        if let window = NSApp.windows.first {
            var frame = window.frame
            let newHeight = max(totalHeight, 650)  // Minimum 650px height
            let heightDiff = newHeight - frame.size.height
            frame.size.height = newHeight
            frame.origin.y -= heightDiff  // Adjust origin to keep window anchored at top
            window.setFrame(frame, display: true, animate: true)
        }
    }

    func appendCodeSnippets(to html: String) -> String {
        var result = html

        // Find the closing </body> or </html> tag
        let closingBodyRange = result.range(of: "</body>", options: .backwards)
        let closingHtmlRange = result.range(of: "</html>", options: .backwards)

        // Build snippets to append
        let enabledSnippets = codeSnippets.filter { $0.enabled }
        guard !enabledSnippets.isEmpty else {
            return html
        }

        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/makeHTML")

        // Read snippet code from files or use inline code
        var snippetCodes: [String] = []
        for snippet in enabledSnippets {
            if let filePath = snippet.file {
                // Read from file
                let snippetFile = configDir.appendingPathComponent(filePath)
                if let fileContent = try? String(contentsOf: snippetFile, encoding: .utf8) {
                    snippetCodes.append(fileContent)
                }
            } else if let inlineCode = snippet.code {
                // Use inline code (legacy support)
                snippetCodes.append(inlineCode)
            }
        }

        guard !snippetCodes.isEmpty else {
            return html
        }

        let snippetCode = snippetCodes.joined(separator: "\n\n")

        // Insert before closing tag
        if let bodyRange = closingBodyRange {
            result.insert(contentsOf: "\n\n" + snippetCode + "\n", at: bodyRange.lowerBound)
        } else if let htmlRange = closingHtmlRange {
            result.insert(contentsOf: "\n" + snippetCode + "\n", at: htmlRange.lowerBound)
        } else {
            // No closing tags found, just append
            result += "\n\n" + snippetCode
        }

        return result
    }

    func openConfigFolder() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/makeHTML")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        NSWorkspace.shared.open(configDir)
    }

    func editConfig() {
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/makeHTML/config.json")

        // Create default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configFile.path) {
            createDefaultConfig(at: configFile)
        }

        openInEditor(url: configFile)
    }

    func openInEditor(url: URL) {
        // Try to open in VS Code
        let vsCodePath = "/usr/local/bin/code"
        if FileManager.default.fileExists(atPath: vsCodePath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: vsCodePath)
            process.arguments = [url.path]
            try? process.run()
        } else {
            // Fallback to default text editor
            NSWorkspace.shared.open(url)
        }
    }

    func getStylesheetURL() -> URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/makeHTML/preview.css")
    }

    func createDefaultStylesheet(at url: URL) {
        // Copy the bundled preview.css instead of using hardcoded CSS
        // This ensures the stylesheet can be updated without recompiling

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Copy bundled preview.css
        if let bundledCSSPath = Bundle.main.path(forResource: "preview", ofType: "css") {
            let bundledCSSURL = URL(fileURLWithPath: bundledCSSPath)
            try? FileManager.default.copyItem(at: bundledCSSURL, to: url)
        }
    }

    func createDefaultConfig(at url: URL) {
        // Copy the bundled config.json instead of duplicating the config definition
        // This ensures Swift and Python stay in sync - single source of truth

        let configDir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Copy bundled default config.json
        if let bundledConfigPath = Bundle.main.path(forResource: "config", ofType: "json") {
            let bundledConfigURL = URL(fileURLWithPath: bundledConfigPath)
            try? FileManager.default.copyItem(at: bundledConfigURL, to: url)
        }

        // Copy snippet files from app bundle
        copySnippetFiles(to: configDir)
    }

    func copySnippetFiles(to configDir: URL) {
        let snippetsDir = configDir.appendingPathComponent("snippets")

        // Create snippets directory if it doesn't exist
        try? FileManager.default.createDirectory(at: snippetsDir, withIntermediateDirectories: true)

        // Get bundled snippet files
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let bundledSnippetsDir = URL(fileURLWithPath: resourcePath).appendingPathComponent("snippets")

        // Copy each snippet file from bundle to config directory
        if let snippetFiles = try? FileManager.default.contentsOfDirectory(at: bundledSnippetsDir, includingPropertiesForKeys: nil) {
            for sourceFile in snippetFiles where sourceFile.pathExtension == "html" {
                let destFile = snippetsDir.appendingPathComponent(sourceFile.lastPathComponent)
                // Only copy if it doesn't already exist (don't overwrite user edits)
                if !FileManager.default.fileExists(atPath: destFile.path) {
                    try? FileManager.default.copyItem(at: sourceFile, to: destFile)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
