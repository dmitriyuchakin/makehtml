# DOCX2HTML - Native macOS App

A native macOS application built with Swift/SwiftUI that provides a beautiful interface for converting DOCX files to HTML.

## Features

✅ **Native macOS Experience**
- Clean, modern SwiftUI interface
- Drag and drop DOCX files
- Real-time conversion status
- HTML preview after conversion

✅ **Working Config Buttons**
- "Open Config Folder" - Opens Finder to config directory
- "Edit in VS Code" - Opens config.json directly in VS Code
- No navigation issues or browser limitations

✅ **Uses Your Python Converter**
- Bundles your existing `docx2html` executable
- All conversion logic stays the same
- Same config file location: `~/Library/Application Support/DOCX2HTML/config.json`

## Building the App

### Prerequisites

1. macOS 13 (Ventura) or later
2. Xcode Command Line Tools:
   ```bash
   xcode-select --install
   ```

3. Your Python converter built:
   ```bash
   cd ..
   ./build-app.sh
   ```

### Build Steps

1. Navigate to this directory:
   ```bash
   cd DOCX2HTML-Swift
   ```

2. Run the build script:
   ```bash
   ./build.sh
   ```

3. The app will be created at:
   ```
   build/DOCX2HTML.app
   ```

### Running the App

Option 1 - Run directly:
```bash
open build/DOCX2HTML.app
```

Option 2 - Install to Applications:
```bash
cp -r build/DOCX2HTML.app /Applications/
open /Applications/DOCX2HTML.app
```

## How to Use

1. **Launch the app** - You'll see a clean dropzone interface

2. **Drop a .docx file** - Drag any DOCX file onto the window

3. **View results** - The app shows:
   - Conversion status
   - Preview of generated HTML
   - Location of output file

4. **Access config**:
   - Click "Open Config Folder" to browse config directory in Finder
   - Click "Edit in VS Code" to edit config.json directly

## File Structure

```
DOCX2HTML.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── DOCX2HTML (Swift executable)
│   └── Resources/
│       └── docx2html (Python converter)
```

## Advantages Over Platypus

| Feature | Native Swift App | Platypus |
|---------|-----------------|----------|
| App Size | ~10 MB | ~50+ MB |
| Config Buttons | ✅ Work perfectly | ❌ Navigation issues |
| Build Process | Simple shell script | 3-layer abstraction |
| Performance | Native speed | Shell wrapper overhead |
| UI Customization | Full control | Limited |
| Debugging | Standard Xcode tools | Multiple layers |

## Development

### Project Files

- `DOCX2HTMLApp.swift` - App entry point and window configuration
- `ContentView.swift` - Main UI and business logic
- `build.sh` - Build script that compiles and bundles everything

### Making Changes

1. Edit the Swift files
2. Run `./build.sh`
3. Test with `open build/DOCX2HTML.app`

### Customization Ideas

- Add a menu bar with "About" and "Preferences"
- Add file picker button (in addition to drag-drop)
- Show conversion history
- Add batch conversion support
- Preview HTML in embedded WKWebView

## Troubleshooting

### "Cannot verify developer" error
Run this to remove quarantine:
```bash
xattr -dr com.apple.quarantine build/DOCX2HTML.app
```

### VS Code button doesn't work
Make sure VS Code CLI is installed:
1. Open VS Code
2. Press Cmd+Shift+P
3. Type "Shell Command: Install 'code' command in PATH"

### Converter not found
Make sure you've built the Python executable first:
```bash
cd ..
./build-app.sh
```

## Next Steps

This is a basic implementation. You can extend it with:
- Settings window for editing config visually
- Multiple theme support
- Export options (copy to clipboard, etc.)
- Integration with other file formats
- Network-based conversion for team collaboration

## License

Same as your Python converter.

## New Features - HTML Preview

### Live HTML Rendering
The preview now renders the actual HTML using WKWebView instead of showing raw code:
- ✅ Real-time preview of converted HTML
- ✅ Customizable styling with CSS
- ✅ Reload button to refresh preview after CSS changes

### Custom Stylesheet
A new `preview.css` file is automatically created at:
```
~/Library/Application Support/DOCX2HTML/preview.css
```

Features:
- **Default styling** - Clean, GitHub-like appearance
- **Fully customizable** - Edit the CSS to match your preferences
- **Hot reload** - Click "Reload" button to see CSS changes
- **Edit button** - Click "Edit preview.css" to open in VS Code

### Three Config Buttons
1. **Open Config Folder** - Opens ~/Library/Application Support/DOCX2HTML/ in Finder
2. **Edit config.json** - Opens conversion configuration in VS Code
3. **Edit preview.css** - Opens preview stylesheet in VS Code

### Preview Styling
The default `preview.css` includes styles for:
- Typography (headings, paragraphs, links)
- Tables with alternating row colors
- Blockquotes with left border
- Code blocks with monospace font
- Lists and images
- Special characters (©, ®, ™) as superscript

You can customize any of these styles by editing `preview.css`!

