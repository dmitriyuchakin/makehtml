# Claude Context: makeHTML Project

**Last Updated**: 2025-12-02
**Project**: makeHTML - Native macOS DOCX to HTML Converter
**Language**: Swift 5.9+ / SwiftUI
**Target**: macOS 14.0+ (Sonoma)
**Current Branch**: swift

---

## Project Overview

A pure Swift/SwiftUI native macOS app that converts Microsoft Word (.docx) files to clean, formatted HTML without any external dependencies (except build-time tidy requirement).

### Key Features
- **Native DOCX parsing** - Direct XML parsing, no python-docx library
- **Bundled HTML Tidy** - 835KB tidy binary included in app bundle
- **Automatic validation** - Text comparison between DOCX and HTML output
- **Highly configurable** - JSON-based config with 7+ configuration sections
- **Self-contained** - No dependencies for end users

---

## Architecture

### Conversion Flow
```
DOCX File
  ↓
Extract ZIP → Parse document.xml + rels
  ↓
Build internal structure (DocxDocument)
  ↓
Merge consecutive runs (reduce HTML bloat)
  ↓
Render to HTML (paragraphs, tables, lists)
  ↓
Apply transformations (special chars, replacements)
  ↓
Format with bundled tidy binary
  ↓
Validate (compare plain text)
  ↓
Display preview with custom CSS
```

### Key Source Files

**makeHTMLApp.swift** (31 lines)
- App entry point with @main attribute
- NSApplicationDelegate for "Open With" support
- NotificationCenter for file URL passing
- Window configuration: hidden title bar, 700x720 default size

**ContentView.swift** (~500 lines)
- Main UI with drag & drop
- Conversion orchestration
- Status display (success/warning/error)
- HTML preview with WKWebView
- Config/preview.css edit buttons

**DocxXMLParser.swift** (~400 lines)
- SAX-style XMLParser delegate
- Parses document.xml preserving whitespace
- Extracts paragraphs, tables, runs, hyperlinks
- Reads _rels/document.xml.rels for link targets

**DocxConverter.swift** (~900 lines)
- Core conversion logic
- Configuration models (Codable structs)
- HTML generation with proper nesting
- Run merging (consolidate consecutive same-format runs)
- Text replacements with regex + formatting awareness
- Special character wrapping
- Quote detection
- Link handling with target="_blank" exceptions
- HTML Tidy integration (bundled binary)
- Validation system (plain text comparison)

**ConversionLogger.swift** (~200 lines)
- Daily log files: `~/Library/Application Support/makeHTML/logs/YYYY-MM-DD.log`
- 30-day auto-rotation
- Detailed conversion logging
- Opens logs in default editor

---

## Configuration System

Location: `~/Library/Application Support/makeHTML/config.json`

### 1. Output Settings
```json
{
  "output": {
    "paragraph_tag": "p",
    "heading_tag": "h3"
  }
}
```

### 2. Special Characters
Auto-wraps ©, ®, ™ in `<sup>` tags (configurable)

### 3. Text Replacements
- Regex-based find/replace
- Handles text split across `<u>` tags
- Won't replace inside HTML attributes (prevents nested anchors)
- Example: `news.aa.com` → `<a href="...">news.aa.com</a>`

### 4. Link Handling
- Auto-adds `target="_blank"` to hyperlinks
- Exception domains: news.aa.com, jetnet.aa.com (configurable)

### 5. Quote Detection
- Wraps paragraphs starting with quotes in custom tags
- Configurable threshold (minimum lines)

### 6. HTML Tidy Formatting ⭐
```json
{
  "tidy_formatting": {
    "enabled": true,
    "indent_spaces": 2,
    "wrap_length": 80,
    "vertical_space": false,
    "show_body_only": true,
    "custom_options": []
  }
}
```
- Binary bundled at `Contents/Resources/tidy`
- Fallback to system tidy if bundled missing
- Graceful degradation if tidy not found

### 7. Code Snippets
HTML templates in `snippets/*.html` folder

---

## Build Process

### Prerequisites
1. **Xcode Command Line Tools**: `xcode-select --install`
2. **HTML Tidy** (build-time only): `brew install tidy-html5`

### Build Script Flow
```bash
./build.sh
```

1. Find tidy binary on system (`/opt/homebrew/bin/tidy`, etc.)
2. Create temporary copy: `./tidy-binary`
3. Compile Swift with `swiftc` (5 source files)
4. Bundle resources:
   - Copy tidy to `Contents/Resources/tidy`
   - Include config.json, preview.css, snippets
   - Add header icons (light/dark mode)
5. Generate app icon from PNG (multiple resolutions)
6. Code sign with ad-hoc signature
7. **Clean up `./tidy-binary`** (important!)

**Output**: `build/makeHTML.app` (~5 MB)

---

## Important Implementation Details

### 1. Run Merging (Lines 428-482 in DocxConverter.swift)
Word splits text into multiple runs for editing history. We merge consecutive runs with identical formatting to reduce HTML bloat:

```
Before: <strong>A</strong><strong>B</strong><strong>C</strong>
After:  <strong>ABC</strong>
```

### 2. Replacement System (Lines 673-870 in DocxConverter.swift)
**Challenge**: Text can be split across formatting tags in DOCX
- "Facebook.com/AmericanAirlines" might be `<u>Facebook.com/</u><u>AmericanAirlines</u>`

**Solution**:
- Distinguish formatting tags (u, em, strong) from structural tags (a, p, h1)
- Process text segments with formatting tags included
- Regex pattern allows `(?:</u><u>)?` between characters
- Won't replace inside structural tag attributes (prevents nested anchors)

### 3. Tidy Integration (Lines 248-359 in DocxConverter.swift)
**Binary Location Priority**:
1. Bundled: `Bundle.main.resourcePath/tidy`
2. Homebrew (Apple Silicon): `/opt/homebrew/bin/tidy`
3. Homebrew (Intel): `/usr/local/bin/tidy`
4. System: `/usr/bin/tidy`

**If not found**: Returns unformatted HTML (no error)

**Configuration**: Read from `config.tidyFormatting` (optional field)

### 4. Validation System (Lines 403-470 in DocxConverter.swift)
**Process**:
1. Extract plain text from DOCX XML
2. Strip HTML tags from output
3. Normalize whitespace (collapse multiple spaces/newlines)
4. Compare character counts
5. Report differences with position/type

**Result Types**:
- `.success` - Green circle
- `.warning(count)` - Orange triangle + log file button
- `.error(message)` - Red X + error details

### 5. "Open With" Support (makeHTMLApp.swift)
```swift
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.pathExtension.lowercased() == "docx" {
        NotificationCenter.default.post(name: .openDocxFile, object: url)
    }
}
```

ContentView listens for notification and triggers conversion.

---

## Known Issues & Limitations

### Not Supported
- ❌ Images (DOCX images not extracted/embedded)
- ❌ Charts, equations, embedded objects
- ❌ Complex table merging (partially supported)
- ❌ Font colors, custom fonts
- ❌ Headers/footers
- ❌ Comments, track changes
- ❌ Styles (only inline formatting preserved)

### Supported Formatting
- ✅ Bold, italic, underline
- ✅ Superscript, subscript
- ✅ Hyperlinks
- ✅ Tables (basic)
- ✅ Lists (bullet, numbered, nested)
- ✅ Headings (configurable tag)
- ✅ Special characters (©, ®, ™)

---

## Testing

### Batch Validation
```bash
swiftc -o test-batch-cli test-batch.swift DocxXMLParser.swift DocxConverter.swift ConversionLogger.swift
./test-batch-cli
```
Tests all `.docx` files in `../test docs/` directory

### Single File Validation
```bash
swiftc -o test-validation-cli test-validation.swift DocxXMLParser.swift DocxConverter.swift ConversionLogger.swift
./test-validation-cli "path/to/file.docx"
```

### Debug Mode
Set `debugForceWarnings = true` at ContentView.swift:69 to test warning UI

---

## File Structure

```
makeHTML-Swift/
├── Source Files
│   ├── makeHTMLApp.swift           # App entry point
│   ├── ContentView.swift           # Main UI
│   ├── DocxXMLParser.swift         # XML parsing
│   ├── DocxConverter.swift         # Conversion logic
│   └── ConversionLogger.swift      # Logging system
│
├── Testing
│   ├── test-batch.swift            # Batch validation script
│   ├── test-validation.swift       # Single file validation
│   └── test-cli.swift              # Basic CLI test
│
├── Build & Config
│   ├── build.sh                    # Build script
│   ├── Package.swift               # SPM config (no dependencies)
│   ├── config.json                 # Default config template
│   └── .gitignore                  # Git ignore rules
│
├── Resources
│   ├── makeHTML-icon.png           # App icon source (1024x1024)
│   ├── header-icon-light-600.png  # UI header (light mode)
│   ├── header-icon-dark-600.png   # UI header (dark mode)
│   ├── preview.css                 # HTML preview styling
│   └── snippets/                   # HTML snippet templates
│       ├── photo-grid-3x1.html
│       ├── photo-grid-2x1.html
│       ├── photo-with-caption.html
│       └── embed-container.html
│
└── Documentation
    ├── README.md                   # Comprehensive docs (494 lines)
    └── CLAUDE.md                   # This file

Build Outputs (gitignored):
├── build/makeHTML.app              # Final app bundle
├── .build/                         # SPM build cache
└── tidy-binary                     # Temporary (deleted by build.sh)
```

---

## Common Tasks

### Adding a New Config Option

1. Add to struct in DocxConverter.swift:
```swift
struct ConversionConfig: Codable {
    let newOption: NewOptionType

    enum CodingKeys: String, CodingKey {
        case newOption = "new_option"
    }
}
```

2. Add to config.json template
3. Use in conversion logic
4. Document in README.md

### Adding a New Tidy Option

Update `TidyFormatting` struct and `formatHTML()` function to handle new option.

### Debugging Conversion Issues

1. Check log: `~/Library/Application Support/makeHTML/logs/YYYY-MM-DD.log`
2. Enable debug mode: `debugForceWarnings = true`
3. Run validation test on specific file
4. Check DOCX XML directly: `unzip -p file.docx word/document.xml`

---

## Git Workflow

### Ignored Files (.gitignore)
- Build outputs: `build/`, `.build/`, `*.app`
- Temp files: `tidy-binary`, `test-*-cli`
- macOS: `.DS_Store`
- Xcode: `*.xcodeproj`
- SPM: `Package.resolved`
- Claude: `../.claude/`

### Commit Guidelines
Only commit source files, configs, and documentation. Never commit binaries or build outputs.

---

## Troubleshooting Reference

### Build fails - "tidy not found"
**Solution**: `brew install tidy-html5` (only needed for building, not using)

### Conversion validation fails
**Check**: Log file for specific differences
**Common cause**: Unsupported DOCX features (charts, equations)

### HTML preview blank
**Check**: `~/Library/Application Support/makeHTML/preview.css` exists

### Nested anchor tags in output
**Fixed in**: DocxConverter.swift lines 673-870
**Solution**: Replacements now distinguish formatting vs structural tags

### Sporadic nesting (multiple same tags)
**Fixed in**: DocxConverter.swift lines 428-482
**Solution**: Run merging consolidates consecutive same-format runs

---

## Version History

### Current (v0.5 Build 1111)
- ✅ Pure Swift implementation (no Python)
- ✅ Bundled tidy binary for HTML formatting
- ✅ Configurable tidy options in config.json
- ✅ Run merging for cleaner HTML
- ✅ Smart replacements (handles split text, avoids nested anchors)
- ✅ Validation system with logging
- ✅ "Open With" support
- ✅ Comprehensive documentation

### Previous
- Python-based with Platypus wrapper (deprecated)
- SwLibTidy attempt (abandoned due to type conflicts)

---

## Future Enhancement Ideas

From README.md:
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

## Notes for Claude

### When Debugging
- Always check logs first: `~/Library/Application Support/makeHTML/logs/`
- Run batch validation to catch regressions
- Test with files in `../test docs/` directory

### When Adding Features
- Update all 4 places: Code → Config → README → This file
- Test with batch validation before committing
- Maintain backward compatibility for config.json

### When Reviewing Code
- ContentView.swift:69 - Debug flag location
- DocxConverter.swift:428-482 - Run merging logic
- DocxConverter.swift:673-870 - Replacement system
- DocxConverter.swift:248-359 - Tidy integration
- DocxConverter.swift:403-470 - Validation system

### Project Conventions
- Config keys: snake_case in JSON, camelCase in Swift structs
- HTML tags: lowercase (`<p>`, not `<P>`)
- Indentation: 2 spaces (matches tidy default)
- Line length: Try to keep under 100 chars
- Comments: Explain "why" not "what"

---

**Last Updated**: 2025-12-02 by Claude (Sonnet 4.5)
**Latest Commit**: 98ae208 - "full swift version"
