import SwiftUI
import WebKit
import UniformTypeIdentifiers

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

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("📄 DOCX2HTML")
                    .font(.system(size: 48))
                Text("Converter")
                    .font(.title2)
                    .foregroundColor(.secondary)
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

                Text("~/Library/Application Support/DOCX2HTML/")
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

                    Button(action: editStylesheet) {
                        Label("Edit preview.css", systemImage: "paintbrush")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(minWidth: 700, minHeight: 700)
        .onAppear {
            loadStylesheet()
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
        guard let converterPath = Bundle.main.path(forResource: "docx2html", ofType: nil) else {
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
                if let htmlString = try? String(contentsOf: outputURL) {
                    DispatchQueue.main.async {
                        self.statusMessage = "✓ Converted successfully: \(outputURL.lastPathComponent)"
                        self.htmlContent = htmlString
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
        if let css = try? String(contentsOf: styleURL) {
            cssContent = css
        }
    }

    func openConfigFolder() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DOCX2HTML")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        NSWorkspace.shared.open(configDir)
    }

    func editConfig() {
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DOCX2HTML/config.json")

        // Create default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configFile.path) {
            createDefaultConfig(at: configFile)
        }

        openInEditor(url: configFile)
    }

    func editStylesheet() {
        let styleURL = getStylesheetURL()

        // Create default stylesheet if it doesn't exist
        if !FileManager.default.fileExists(atPath: styleURL.path) {
            createDefaultStylesheet(at: styleURL)
        }

        openInEditor(url: styleURL)
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
            .appendingPathComponent("Library/Application Support/DOCX2HTML/preview.css")
    }

    func createDefaultStylesheet(at url: URL) {
        let defaultCSS = """
        /* DOCX2HTML Preview Stylesheet */
        /* Edit this file to customize how converted HTML appears in the preview */

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #ffffff;
        }

        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
            color: #1a1a1a;
        }

        h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #666; }

        /* Paragraphs */
        p {
            margin-top: 0;
            margin-bottom: 16px;
        }

        /* Links */
        a {
            color: #0366d6;
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        /* Lists */
        ul, ol {
            padding-left: 2em;
            margin-top: 0;
            margin-bottom: 16px;
        }

        li {
            margin-bottom: 0.25em;
        }

        /* Blockquotes */
        blockquote {
            margin: 0;
            padding: 0 1em;
            color: #666;
            border-left: 0.25em solid #dfe2e5;
            margin-bottom: 16px;
        }

        /* Tables */
        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }

        table th,
        table td {
            padding: 6px 13px;
            border: 1px solid #dfe2e5;
        }

        table th {
            font-weight: 600;
            background-color: #f6f8fa;
        }

        table tr {
            background-color: #fff;
            border-top: 1px solid #c6cbd1;
        }

        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }

        /* Code */
        code {
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            background-color: rgba(27, 31, 35, 0.05);
            border-radius: 3px;
            font-family: 'SF Mono', Monaco, 'Courier New', monospace;
        }

        /* Superscript (for special characters) */
        sup {
            font-size: 0.75em;
            vertical-align: super;
            color: #666;
        }

        /* Strong/Bold */
        strong {
            font-weight: 600;
        }

        /* Emphasis/Italic */
        em {
            font-style: italic;
        }

        /* Horizontal Rule */
        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: #e1e4e8;
            border: 0;
        }

        /* Images */
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 16px 0;
        }
        """

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? defaultCSS.write(to: url, atomically: true, encoding: .utf8)
    }

    func createDefaultConfig(at url: URL) {
        let defaultConfig = """
        {
          "output": {
            "paragraph_tag": "p",
            "heading_tag": "h3"
          },
          "special_characters": [
            {
              "character": "©",
              "wrap_tag": "sup",
              "enabled": true
            },
            {
              "character": "®",
              "wrap_tag": "sup",
              "enabled": true
            },
            {
              "character": "™",
              "wrap_tag": "sup",
              "enabled": true
            }
          ],
          "replacements": [
            {
              "search": "@AmericanAir",
              "replace": "<a target=\\"blank\\" href=\\"https:/x.com/AmericanAir\\">@AmericanAir</a>",
              "case_sensitive": true
            },
            {
              "search": "news.aa.com",
              "replace": "<a href=\\"https://news.aa.com\\">news.aa.com</a>",
              "case_sensitive": true
            },
            {
              "search": "Facebook.com/AmericanAirlines",
              "replace": "<a target=\\"blank\\" href=\\"https://facebook.com/AmericanAirlines\\">Facebook.com/AmericanAirlines</a>",
              "case_sensitive": true
            },
            {
              "search": "oneworld",
              "replace": "<strong>one</strong>world",
              "case_sensitive": true
            },
            {
              "search": "\\u202F",
              "replace": " ",
              "case_sensitive": false
            }
          ],
          "quote_detection": {
            "enabled": true,
            "threshold": 3,
            "wrap_tag": "blockquote",
            "quote_types": ["\\"", "\\u201C", "\\u201D", "\\u2018", "\\u2019"]
          }
        }
        """

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? defaultConfig.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
