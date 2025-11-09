# Packaging DOCX2HTML as a macOS App

This guide explains how to package the DOCX2HTML converter as a standalone macOS application with a dropzone interface.

## Overview

The packaging process uses two tools:
1. **PyInstaller** - Creates a standalone executable with all Python dependencies bundled
2. **Platypus** - Creates a native macOS app with a dropzone interface

The final app requires **no Python installation** or dependencies from end users.

## Prerequisites

### 1. Install PyInstaller

```bash
pip3 install pyinstaller
```

### 2. Install Platypus

```bash
brew install platypus
```

Or download from: https://sveinbjorn.org/platypus

## Automated Build

The easiest way to build the app is using the automated build script:

```bash
./build-app.sh
```

This script will:
1. Check for required dependencies
2. Clean previous builds
3. Build the standalone executable with PyInstaller
4. Test the executable
5. Create the macOS app bundle with Platypus

### Output

After running the build script, you'll find:
- `dist/docx2html` - Standalone command-line executable
- `dist/DOCX2HTML.app` - Complete macOS application with dropzone

## Manual Build Process

If you prefer to build manually or need to customize the process:

### Step 1: Build with PyInstaller

```bash
pyinstaller --name docx2html \
    --onefile \
    --console \
    --hidden-import=docx \
    --hidden-import=docx.shared \
    --hidden-import=docx.oxml \
    --hidden-import=docx.text \
    --hidden-import=docx.table \
    --hidden-import=lxml \
    --hidden-import=lxml.etree \
    --hidden-import=lxml._elementpath \
    docx2html.py
```

This creates `dist/docx2html` - a standalone executable.

### Step 2: Build with Platypus CLI

```bash
platypus \
    --name "DOCX2HTML" \
    --interface "Text Window" \
    --interpreter "/bin/bash" \
    --app-icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/DocumentIcon.icns" \
    --author "DOCX2HTML" \
    --bundle-identifier "com.docx2html.converter" \
    --app-version "1.0.0" \
    --droppable \
    --accept-files \
    --accept-text \
    --suffixes "docx" \
    --bundled-file "dist/docx2html" \
    platypus-wrapper.sh \
    "dist/DOCX2HTML.app"
```

### Step 3: Build with Platypus GUI (Alternative)

If you prefer using the Platypus GUI:

1. Open Platypus application
2. Configure the following settings:
   - **Script Path**: Select `platypus-wrapper.sh`
   - **Script Type**: `/bin/bash`
   - **Interface**: "Text Window"
   - **App Name**: "DOCX2HTML"
   - **Author**: Your name
   - **Identifier**: `com.docx2html.converter`
   - **Version**: 1.0.0

3. Under "Settings" tab:
   - ✓ Accept dropped items
   - ✓ Accept dropped files
   - Document types: `docx`

4. Under "Bundled Files" tab:
   - Click "+" and add `dist/docx2html`

5. Click "Create App" and save to `dist/DOCX2HTML.app`

## Configuration

### Hybrid Configuration System

The app uses a hybrid configuration approach:

1. **First Priority**: `~/Library/Application Support/DOCX2HTML/config.json`
2. **Second Priority**: Script directory `config.json` (backwards compatibility)
3. **Default**: Creates config with defaults on first run

### User Instructions

End users can customize conversion by editing:
```
~/Library/Application Support/DOCX2HTML/config.json
```

To access this location:
1. Open Finder
2. Press `Cmd + Shift + G`
3. Type: `~/Library/Application Support/DOCX2HTML`
4. Edit `config.json` with TextEdit

## Distribution

### Simple Distribution

1. Build the app using `./build-app.sh`
2. Compress the app:
   ```bash
   cd dist
   zip -r DOCX2HTML.zip DOCX2HTML.app
   ```
3. Share `DOCX2HTML.zip` with users

### Installation for End Users

1. Download and unzip `DOCX2HTML.zip`
2. Drag `DOCX2HTML.app` to Applications folder
3. Double-click the app to open
4. Drop .docx files onto the app window or app icon
5. HTML files will be created in the same directory

On first run, a config file is automatically created at:
`~/Library/Application Support/DOCX2HTML/config.json`

### macOS Security

When first running the app, macOS may show a security warning. Users should:

1. Right-click (or Control-click) the app
2. Select "Open"
3. Click "Open" in the dialog

Alternatively, go to System Preferences > Security & Privacy and click "Open Anyway".

## Advanced: Code Signing

For wider distribution, you should code sign the app:

```bash
# Sign the executable
codesign --force --deep --sign "Developer ID Application: Your Name" dist/docx2html

# Sign the app bundle
codesign --force --deep --sign "Developer ID Application: Your Name" dist/DOCX2HTML.app

# Verify
codesign --verify --verbose dist/DOCX2HTML.app
```

## Advanced: Notarization

For macOS 10.15 (Catalina) and later, you should notarize the app:

1. Create a zip of the app
2. Submit for notarization:
   ```bash
   xcrun notarytool submit DOCX2HTML.zip \
       --apple-id "your@email.com" \
       --team-id "YOUR_TEAM_ID" \
       --wait
   ```
3. Staple the notarization ticket:
   ```bash
   xcrun stapler staple DOCX2HTML.app
   ```

## Troubleshooting

### PyInstaller Issues

**Problem**: Import errors when running the executable

**Solution**: Add missing modules to hidden imports in `build-app.sh`:
```bash
--hidden-import=module_name
```

### Platypus Issues

**Problem**: App doesn't accept dropped files

**Solution**: Ensure in Platypus settings:
- "Accept dropped items" is checked
- "Accept dropped files" is checked
- Document types includes "docx"

### Config Issues

**Problem**: Config file not being found

**Solution**: The app creates the config on first run. Check:
```bash
ls -la ~/Library/Application\ Support/DOCX2HTML/
```

## File Structure

```
docx-html/
├── docx2html.py              # Main Python script
├── config.json               # Development config (optional)
├── platypus-wrapper.sh       # Wrapper script for Platypus
├── build-app.sh              # Automated build script
├── requirements.txt          # Python dependencies
├── README.md                 # User documentation
├── PACKAGING.md              # This file
└── dist/                     # Build output (created by build script)
    ├── docx2html             # Standalone executable
    └── DOCX2HTML.app         # macOS app bundle
```

## Size Considerations

The final app size will be approximately:
- Standalone executable: ~40-60 MB
- Complete app bundle: ~50-80 MB

This includes:
- Python runtime
- python-docx library
- lxml library
- All dependencies

## Updates

To update the app after making changes:

1. Modify the source code (`docx2html.py`)
2. Run the build script again:
   ```bash
   ./build-app.sh
   ```
3. Test the new `dist/DOCX2HTML.app`
4. Redistribute to users

User configurations in `~/Library/Application Support/DOCX2HTML/` will be preserved across updates.

## Support

For issues or questions:
- Check that all dependencies are installed
- Verify the standalone executable works: `./dist/docx2html --help`
- Test with a sample .docx file
- Check console output in Platypus "Text Window" mode
