# makeHTML - DOCX to HTML Converter

A native macOS application built with Swift/SwiftUI for converting Microsoft Word (DOCX) files to clean, formatted HTML.

## Quick Start

### 1. Build the App

```bash
cd makeHTML-Swift
./build.sh
```

### 2. Run It

```bash
open build/makeHTML.app
```

### 3. Convert Files

- Drag and drop a .docx file onto the app window
- View the HTML preview
- Click "Open HTML" to see the output file

That's it! No dependencies, no Python, no Homebrew required (tidy is bundled).

---

## Features

### ✅ Pure Swift Implementation
- **No external dependencies** - Everything is bundled
- **Native DOCX parsing** - Direct XML parsing of DOCX files
- **Fast conversion** - Native Swift performance
- **Self-contained** - Single app bundle, no installers needed

### ✅ Professional HTML Output
- **Bundled HTML Tidy** - Automatic HTML formatting (835KB binary included)
- **Configurable formatting** - Control indentation, wrapping, spacing
- **Clean output** - Properly formatted, readable HTML
- **Validation** - Automatic text comparison between DOCX and HTML

### ✅ Modern macOS Experience
- **SwiftUI interface** - Native macOS design
- **Drag and drop** - Simple file handling
- **Live preview** - WebKit-based HTML rendering with custom CSS
- **Real-time status** - Conversion progress and validation results
- **"Open With" support** - Right-click .docx files in Finder

### ✅ Highly Configurable
- **Text replacements** - Custom find/replace patterns with regex support
- **Special characters** - Auto-wrap ©, ®, ™ in tags
- **Link handling** - Automatic target="_blank" with domain exceptions
- **Quote detection** - Auto-wrap quoted paragraphs
- **HTML snippets** - Insert reusable HTML templates
- **Tidy formatting** - Full control over HTML output style

---

## Configuration

All settings are in: `~/Library/Application Support/makeHTML/config.json`

Click **"Edit config.json"** in the app to open it in your default editor.

### Key Configuration Sections

#### 1. Output Settings
```json
"output": {
  "paragraph_tag": "p",
  "heading_tag": "h3"
}
```

#### 2. Text Replacements
```json
"replacements": [
  {
    "search": "news.aa.com",
    "replace": "<a href=\"https://news.aa.com\">news.aa.com</a>",
    "case_sensitive": true
  }
]
```
- Supports regex patterns
- Handles text split across formatting tags
- Won't replace inside existing HTML attributes

#### 3. Special Characters
```json
"special_characters": [
  {
    "character": "©",
    "wrap_tag": "sup",
    "enabled": true
  }
]
```

#### 4. Link Handling
```json
"link_handling": {
  "enabled": true,
  "add_target_blank": true,
  "exception_domains": ["news.aa.com", "jetnet.aa.com"]
}
```
- Auto-adds `target="_blank"` to external links
- Whitelist domains to exclude from target="_blank"

#### 5. Quote Detection
```json
"quote_detection": {
  "enabled": true,
  "threshold": 3,
  "wrap_tag": "div class=\"blockquote\"",
  "quote_types": ["\"", """, """]
}
```
- Automatically wraps paragraphs starting with quotes
- Configurable threshold (minimum lines to detect)

#### 6. HTML Tidy Formatting ⭐ NEW
```json
"tidy_formatting": {
  "enabled": true,
  "indent_spaces": 2,
  "wrap_length": 80,
  "vertical_space": false,
  "show_body_only": true,
  "custom_options": []
}
```

**Options:**
- `enabled` - Enable/disable HTML formatting
- `indent_spaces` - Number of spaces for indentation (2, 4, etc.)
- `wrap_length` - Max line length (0 = no wrapping)
- `vertical_space` - Add blank lines between elements
- `show_body_only` - Return only body content (no HTML wrapper)
- `custom_options` - Array of additional tidy flags (e.g., `["--uppercase-tags", "yes"]`)

**Examples:**

Compact output (default):
```json
{
  "enabled": true,
  "indent_spaces": 2,
  "wrap_length": 0,
  "vertical_space": false,
  "show_body_only": true,
  "custom_options": []
}
```

Readable with spacing:
```json
{
  "enabled": true,
  "indent_spaces": 4,
  "wrap_length": 80,
  "vertical_space": true,
  "show_body_only": true,
  "custom_options": []
}
```

Disable formatting entirely:
```json
{
  "enabled": false,
  ...
}
```

#### 7. Code Snippets
```json
"code_snippets": [
  {
    "name": "Photo grid 3x1",
    "file": "snippets/photo-grid-3x1.html",
    "enabled": false
  }
]
```
- Insert reusable HTML templates
- Snippet files stored in app resources
- Toggle on/off per snippet

---

## Building the App

### Prerequisites

- **macOS 14.0+** (Sonoma or later)
- **Xcode Command Line Tools**:
  ```bash
  xcode-select --install
  ```
- **HTML Tidy** (for HTML formatting):
  ```bash
  brew install tidy-html5
  ```
  *Note: The build script bundles tidy into the app, so end users don't need it installed. Only required for building.*

### Build Steps

1. Clone or download this repository
2. Navigate to the Swift app directory:
   ```bash
   cd makeHTML-Swift
   ```
3. Run the build script:
   ```bash
   ./build.sh
   ```
4. The app will be created at `build/makeHTML.app`

### Optional: Install to Applications

```bash
cp -r build/makeHTML.app /Applications/
```

### Build Process Details

The build script automatically:
1. **Finds tidy binary** on your system:
   - `/opt/homebrew/bin/tidy` (Homebrew Apple Silicon)
   - `/usr/local/bin/tidy` (Homebrew Intel)
   - `/usr/bin/tidy` (System installation)
   - Creates temporary copy at `./tidy-binary`
2. **Compiles Swift** source files with `swiftc`
3. **Bundles resources**:
   - Copies tidy to `Contents/Resources/tidy` (835KB)
   - Includes config.json, preview.css, snippets
   - Adds header icons
4. **Creates app icon** from makeHTML-icon.png
5. **Code signs** the app bundle
6. **Cleans up** temporary files (tidy-binary)

**Result**: Self-contained app with bundled tidy - no dependencies for end users!

---

## How to Use

### Method 1: Drag & Drop
1. Open makeHTML.app
2. Drag a .docx file onto the window
3. View the HTML preview
4. Click "Open HTML" to open the output file

### Method 2: "Open With"
1. Right-click a .docx file in Finder
2. Select "Open With" → "makeHTML"
3. The app opens with the file converted

### Method 3: Dock
1. Add makeHTML.app to your Dock
2. Drag .docx files onto the dock icon
3. Instant conversion

### Output Location

HTML files are saved next to the original .docx file:
```
/path/to/your-file.docx
/path/to/your-file.html  ← Generated here
```

---

## Architecture

### File Structure

```
makeHTML.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── makeHTML (Swift executable)
│   └── Resources/
│       ├── tidy (HTML Tidy binary - 835KB)
│       ├── config.json (template)
│       ├── preview.css (preview styling)
│       ├── header-icon-light-600.png
│       ├── header-icon-dark-600.png
│       ├── makeHTML.icns (app icon)
│       └── snippets/
│           ├── photo-grid-3x1.html
│           ├── photo-grid-2x1.html
│           ├── photo-with-caption.html
│           └── embed-container.html
```

### Source Files

- **makeHTMLApp.swift** - App entry point, "Open With" support
- **ContentView.swift** - Main UI, drag & drop, conversion orchestration
- **DocxXMLParser.swift** - SAX-style XML parser for DOCX document.xml
- **DocxConverter.swift** - Core conversion logic, HTML generation, validation
- **ConversionLogger.swift** - Daily logging system with auto-rotation

### How It Works

1. **Extract DOCX** - Unzips .docx to access internal XML files
2. **Parse XML** - Reads document.xml and _rels/document.xml.rels
3. **Build Structure** - Creates internal representation (paragraphs, tables, runs)
4. **Merge Runs** - Consolidates consecutive runs with identical formatting
5. **Generate HTML** - Renders HTML with proper tags and attributes
6. **Apply Transformations** - Special characters, replacements, quote detection
7. **Format with Tidy** - Runs bundled tidy binary for clean output
8. **Validate** - Compares plain text from DOCX vs HTML
9. **Display** - Shows preview with custom CSS styling

---

## Validation System

Every conversion is automatically validated:

### What's Validated
- ✅ **Text content** - DOCX plain text vs HTML plain text must match
- ✅ **Character count** - After normalization (whitespace collapsed)
- ✅ **No data loss** - Every character in DOCX appears in HTML
- ✅ **No duplicates** - No text is accidentally repeated

### Validation Process
1. Extract plain text from DOCX XML
2. Strip HTML tags from output
3. Normalize whitespace (collapse multiple spaces/newlines)
4. Compare character counts
5. Report differences if any

### Validation Results
- **Green circle** - Validation passed
- **Orange warning** - Minor issues detected (logged)
- **Red error** - Conversion failed

View logs: Click "View Log File" button when warnings/errors appear

Logs are stored at: `~/Library/Application Support/makeHTML/logs/YYYY-MM-DD.log`

---

## Development

### Making Changes

1. Edit Swift source files
2. Run `./build.sh`
3. Test with `open build/makeHTML.app`

### Testing

**Batch validation** (test all files in `test docs/`):
```bash
swiftc -o test-batch-cli test-batch.swift DocxXMLParser.swift DocxConverter.swift ConversionLogger.swift
./test-batch-cli
```

**Single file validation**:
```bash
swiftc -o test-validation-cli test-validation.swift DocxXMLParser.swift DocxConverter.swift ConversionLogger.swift
./test-validation-cli "path/to/file.docx"
```

### Debugging

**Enable validation warnings in UI** (DocxConverter.swift:69):
```swift
private let debugForceWarnings = true  // Show warning UI for testing
```

**Check logs**:
```bash
open ~/Library/Application\ Support/makeHTML/logs/
```

### Adding Features

Common extension points:

- **New transformations** - Add to `renderDocument()` in DocxConverter.swift
- **Custom HTML tags** - Modify `renderParagraph()` or `renderTable()`
- **UI elements** - Edit ContentView.swift
- **Config options** - Add to ConversionConfig struct and config.json
- **Tidy options** - Extend TidyFormatting struct

---

## Troubleshooting

### "Cannot verify developer" error
Remove quarantine flag:
```bash
xattr -dr com.apple.quarantine build/makeHTML.app
```

### Build fails - Xcode not found
Install command line tools:
```bash
xcode-select --install
```

### Tidy binary not found during build
**This only affects building the app, not using it.**

The build script looks for tidy on the **build machine** at:
1. `/opt/homebrew/bin/tidy` (Homebrew on Apple Silicon)
2. `/usr/local/bin/tidy` (Homebrew on Intel)
3. `/usr/bin/tidy` (System installation)

Install with Homebrew:
```bash
brew install tidy-html5
```

If missing during build, you'll see:
```
⚠ Warning: tidy not found. HTML formatting will be skipped.
```

The app still builds and works, but HTML won't be formatted. Once you install tidy and rebuild, the app will include it and end users won't need tidy installed on their machines.

### Config file not created
The app creates config on first run. If missing:
```bash
mkdir -p ~/Library/Application\ Support/makeHTML
cp config.json ~/Library/Application\ Support/makeHTML/
```

### HTML preview is blank
Check preview.css exists:
```bash
ls ~/Library/Application\ Support/makeHTML/preview.css
```

If missing, copy from app resources or create a basic one.

### Conversion validation fails
Check the log file for details:
```bash
cat ~/Library/Application\ Support/makeHTML/logs/$(date +%Y-%m-%d).log
```

Common causes:
- Unsupported DOCX features (equations, charts)
- Corrupted DOCX file
- Complex nested formatting

---

## Advantages Over Python/Platypus Approach

| Feature | makeHTML (Swift) | Python + Platypus |
|---------|------------------|-------------------|
| **Dependencies** | None (all bundled) | Python, pip, packages |
| **App Size** | ~5 MB | ~50+ MB |
| **Startup Time** | Instant | 1-2 seconds |
| **Performance** | Native speed | Interpreter overhead |
| **DOCX Parsing** | Direct XML parsing | python-docx library |
| **Distribution** | Single .app file | Multiple components |
| **Updates** | Rebuild Swift | Update Python packages |
| **Debugging** | Xcode tools | Multiple layers |
| **Config Access** | Native buttons | Shell scripts |

---

## Known Limitations

- **Embedded objects** - Charts, equations, and embedded documents not supported
- **Complex tables** - Merged cells partially supported
- **Styles** - Only inline formatting preserved (bold, italic, underline, etc.)
- **Images** - Not embedded in HTML (DOCX images not extracted)
- **Fonts/Colors** - Not preserved (HTML uses CSS styling instead)
- **Headers/Footers** - Not included in output
- **Comments/Track Changes** - Ignored

For these features, consider exporting from Word directly or using a full-featured library.

---

## Future Enhancement Ideas

- [ ] Image extraction and embedding
- [ ] Custom CSS editor in-app
- [ ] Batch conversion (multiple files)
- [ ] Export to clipboard
- [ ] Settings window (visual config editor)
- [ ] Markdown output option
- [ ] Table of contents generation
- [ ] Custom template support
- [ ] iCloud sync for config
- [ ] Menu bar utility mode

---

## License

MIT License - Free to use, modify, and distribute.

---

## Credits

- **HTML Tidy** - [HTACG/tidy-html5](https://github.com/htacg/tidy-html5) (W3C License)
- **Swift/SwiftUI** - Apple Inc.
- Built with ❤️ for fast, native DOCX to HTML conversion
