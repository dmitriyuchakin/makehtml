# makeHTML Converter

A native macOS application for converting Microsoft Word (.docx) files to clean HTML with customizable output and live preview.

## Project Structure

```
docx-html/
├── makeHTML-Swift/            # Native Swift/SwiftUI macOS app
│   ├── ContentView.swift      # Main UI with drag-drop and preview
│   ├── makeHTMLApp.swift      # App entry point
│   ├── build.sh               # Build script
│   ├── header-icon-light.png  # Light mode logo
│   └── header-icon-dark.png   # Dark mode logo
│
├── makehtml.py                # Python converter (core logic)
├── build-app.sh               # Builds Python executable with PyInstaller
├── dist/                      # Built Python executable
│   └── makehtml
├── requirements.txt           # Python dependencies
└── config.json                # Example configuration
```

## Quick Start

### 1. Build the Python Converter

```bash
./build-app.sh
```

This creates `dist/makehtml` executable.

### 2. Build the Native macOS App

```bash
cd makeHTML-Swift

# Accept Xcode license (one-time)
sudo xcodebuild -license

# Build the app
./build.sh

# Run it
open build/makeHTML.app
```

### 3. Use the App

1. Drop a `.docx` file onto the app window
2. See live HTML preview with custom CSS styling
3. Check code snippets to append custom code to HTML
4. Click "Open HTML" to edit the output in VS Code
5. Click "Edit preview.css" to customize preview styling

## Features

### Native macOS App (Swift/SwiftUI)
- 🎨 **Live HTML Preview** - WKWebView rendering with custom CSS
- 📁 **Working Config Buttons** - No navigation issues
- 🔄 **Hot Reload** - Update CSS and see changes instantly
- 💻 **VS Code Integration** - Open files directly in editor
- 🚀 **Native Performance** - Small bundle (~10 MB)
- 📝 **Code Snippets** - Append custom code to generated HTML
- 🌓 **Adaptive Logo** - Switches between light/dark mode images

### Python Converter
- 📄 **Clean HTML Output** - Configurable paragraph and heading tags
- ✨ **Special Characters** - Wrap ©, ®, ™ in superscript
- 🔄 **Text Replacements** - Custom find/replace with regex support
- 💬 **Quote Detection** - Auto-wrap quoted paragraphs in blockquote
- ⚙️ **JSON Configuration** - Easy to customize

## Configuration

The app creates two configuration files:

### 1. Conversion Config
**Location:** `~/Library/Application Support/makeHTML/config.json`

Controls how DOCX files are converted:
```json
{
  "output": {
    "paragraph_tag": "p",
    "heading_tag": "h3"
  },
  "special_characters": [...],
  "replacements": [...],
  "quote_detection": {...},
  "code_snippets": [
    {
      "name": "Google Analytics",
      "code": "<!-- GA code here -->",
      "enabled": false
    }
  ]
}
```

### 2. Preview Stylesheet
**Location:** `~/Library/Application Support/makeHTML/preview.css`

Controls how HTML appears in the app preview:
- Typography styling
- Table formatting
- Blockquote appearance
- Code blocks
- Link colors
- And more...

## Code Snippets Feature

Add custom HTML/JavaScript to your converted files:

1. Edit `~/Library/Application Support/makeHTML/config.json`
2. Add snippets to the `code_snippets` array
3. Check the snippet checkbox in the app UI
4. Convert a DOCX file - the snippet code is appended to the HTML

Example snippet:
```json
{
  "name": "Google Analytics",
  "code": "<script>\n  // GA tracking code\n</script>",
  "enabled": false
}
```

The app will show a checkbox: "Add Google Analytics to HTML"

## Development

### Python Converter

**Edit:** `makehtml.py`

**Rebuild:**
```bash
./build-app.sh
```

**Test:**
```bash
./dist/makehtml input.docx -o output.html
```

### Swift App

**Edit:** Files in `makeHTML-Swift/`

**Rebuild:**
```bash
cd makeHTML-Swift
./build.sh
```

**Run:**
```bash
open build/makeHTML.app
```

## Requirements

- **macOS:** 13.0 (Ventura) or later
- **Xcode Command Line Tools:** For building Swift app
- **Python 3.9+:** For converter (bundled with PyInstaller)
- **VS Code (optional):** For editing config files

## Architecture

The project uses a two-layer architecture:

1. **Python Converter** (`makehtml.py`)
   - Handles DOCX parsing with python-docx
   - Processes text, formatting, and replacements
   - Generates clean HTML output
   - Bundled as standalone executable

2. **Swift GUI** (`makeHTML-Swift/`)
   - Native macOS interface
   - Calls Python executable via Process()
   - Renders HTML in WKWebView
   - Manages configuration files
   - Appends code snippets to output

This approach combines:
- Python's rich DOCX processing ecosystem
- Swift's native macOS UI capabilities
- Small bundle size (~10 MB)
- Working config buttons without browser limitations

## Testing

### Test Conversion
```bash
./dist/makehtml test.docx -o output.html
```

### Test App
1. Build the app (see Quick Start)
2. Drop a `.docx` file onto the app
3. Verify preview appears
4. Test all buttons:
   - Open HTML
   - Open Config Folder
   - Edit config.json
   - Edit preview.css
   - Reload
5. Test code snippets:
   - Check a snippet checkbox
   - Convert a file
   - Verify snippet code is in the HTML

## Troubleshooting

### "Cannot verify developer" error
```bash
xattr -dr com.apple.quarantine makeHTML-Swift/build/makeHTML.app
```

### Converter not found
Make sure you ran `./build-app.sh` first to create `dist/makehtml`

### VS Code button doesn't work
Install VS Code CLI:
1. Open VS Code
2. Cmd+Shift+P
3. "Shell Command: Install 'code' command in PATH"

### Preview not updating
Click the "Reload" button after editing `preview.css`

### Images not showing in header
Make sure `header-icon-light.png` and `header-icon-dark.png` are in the `makeHTML-Swift/` directory before building.

## License

MIT License - Feel free to use and modify.

## Credits

Built with:
- [python-docx](https://python-docx.readthedocs.io/) - DOCX parsing
- [PyInstaller](https://pyinstaller.org/) - Python bundling
- Swift/SwiftUI - Native macOS interface
