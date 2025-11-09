# DOCX2HTML Converter

A native macOS application for converting Microsoft Word (.docx) files to clean HTML with customizable output and live preview.

## Project Structure

```
docx-html/
├── DOCX2HTML-Swift/          # Native Swift/SwiftUI macOS app
│   ├── ContentView.swift     # Main UI with drag-drop and preview
│   ├── DOCX2HTMLApp.swift    # App entry point
│   ├── build.sh              # Build script
│   ├── README.md             # Swift app documentation
│   └── QUICK-START.md        # Quick build guide
│
├── docx2html.py              # Python converter (core logic)
├── build-app.sh              # Builds Python executable with PyInstaller
├── dist/                     # Built Python executable
│   └── docx2html
├── requirements.txt          # Python dependencies
├── config.json               # Example configuration
└── aa-test.docx              # Test file
```

## Quick Start

### 1. Build the Python Converter

```bash
./build-app.sh
```

This creates `dist/docx2html` executable.

### 2. Build the Native macOS App

```bash
cd DOCX2HTML-Swift

# Accept Xcode license (one-time)
sudo xcodebuild -license

# Build the app
./build.sh

# Run it
open build/DOCX2HTML.app
```

### 3. Use the App

1. Drop a `.docx` file onto the app window
2. See live HTML preview with custom CSS styling
3. Click "Open HTML" to edit the output in VS Code
4. Click "Edit preview.css" to customize preview styling

## Features

### Native macOS App (Swift/SwiftUI)
- 🎨 **Live HTML Preview** - WKWebView rendering with custom CSS
- 📁 **Working Config Buttons** - No navigation issues
- 🔄 **Hot Reload** - Update CSS and see changes instantly
- 💻 **VS Code Integration** - Open files directly in editor
- 🚀 **Native Performance** - Small bundle (~10 MB)

### Python Converter
- 📄 **Clean HTML Output** - Configurable paragraph and heading tags
- ✨ **Special Characters** - Wrap ©, ®, ™ in superscript
- 🔄 **Text Replacements** - Custom find/replace with regex support
- 💬 **Quote Detection** - Auto-wrap quoted paragraphs in blockquote
- ⚙️ **JSON Configuration** - Easy to customize

## Configuration

The app creates two configuration files:

### 1. Conversion Config
**Location:** `~/Library/Application Support/DOCX2HTML/config.json`

Controls how DOCX files are converted:
```json
{
  "output": {
    "paragraph_tag": "p",
    "heading_tag": "h3"
  },
  "special_characters": [...],
  "replacements": [...],
  "quote_detection": {...}
}
```

### 2. Preview Stylesheet
**Location:** `~/Library/Application Support/DOCX2HTML/preview.css`

Controls how HTML appears in the app preview:
- Typography styling
- Table formatting
- Blockquote appearance
- Code blocks
- Link colors
- And more...

## Development

### Python Converter

**Edit:** `docx2html.py`

**Rebuild:**
```bash
./build-app.sh
```

**Test:**
```bash
./dist/docx2html input.docx -o output.html
```

### Swift App

**Edit:** Files in `DOCX2HTML-Swift/`

**Rebuild:**
```bash
cd DOCX2HTML-Swift
./build.sh
```

**Run:**
```bash
open build/DOCX2HTML.app
```

## Requirements

- **macOS:** 13.0 (Ventura) or later
- **Xcode Command Line Tools:** For building Swift app
- **Python 3.9+:** For converter (bundled with PyInstaller)
- **VS Code (optional):** For editing config files

## Architecture

The project uses a two-layer architecture:

1. **Python Converter** (`docx2html.py`)
   - Handles DOCX parsing with python-docx
   - Processes text, formatting, and replacements
   - Generates clean HTML output
   - Bundled as standalone executable

2. **Swift GUI** (`DOCX2HTML-Swift/`)
   - Native macOS interface
   - Calls Python executable via Process()
   - Renders HTML in WKWebView
   - Manages configuration files

This approach combines:
- Python's rich DOCX processing ecosystem
- Swift's native macOS UI capabilities
- Small bundle size (~10 MB vs ~50+ MB with Platypus)
- Working config buttons without browser limitations

## Why This Approach?

**Previous (Platypus):**
- Python → PyInstaller → Platypus wrapper
- 3 layers of abstraction
- Large bundle size (50+ MB)
- WebView button issues (file:// navigation problems)
- Complex build process

**Current (Native Swift):**
- Python → PyInstaller + Swift GUI
- 2 clean layers
- Small bundle size (~10 MB)
- Native buttons that work perfectly
- Simple, maintainable build

## Testing

### Test Conversion
```bash
./dist/docx2html aa-test.docx -o output.html
```

### Test App
1. Build the app (see Quick Start)
2. Drop `aa-test.docx` onto the app
3. Verify preview appears
4. Test all buttons:
   - Open HTML
   - Open Config Folder
   - Edit config.json
   - Edit preview.css
   - Reload

## Troubleshooting

### "Cannot verify developer" error
```bash
xattr -dr com.apple.quarantine DOCX2HTML-Swift/build/DOCX2HTML.app
```

### Converter not found
Make sure you ran `./build-app.sh` first to create `dist/docx2html`

### VS Code button doesn't work
Install VS Code CLI:
1. Open VS Code
2. Cmd+Shift+P
3. "Shell Command: Install 'code' command in PATH"

### Preview not updating
Click the "Reload" button after editing `preview.css`

## License

MIT License - Feel free to use and modify.

## Credits

Built with:
- [python-docx](https://python-docx.readthedocs.io/) - DOCX parsing
- [PyInstaller](https://pyinstaller.org/) - Python bundling
- Swift/SwiftUI - Native macOS interface
