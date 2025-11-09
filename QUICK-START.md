# Quick Start Guide: Building Your DOCX2HTML macOS App

This guide will help you build a standalone macOS app with dropzone interface in just a few minutes.

## What You'll Get

A native macOS application that:
- ✅ Accepts drag & drop of .docx files
- ✅ Converts to clean HTML automatically
- ✅ Works without Python installation (for end users)
- ✅ Stores config in standard macOS location
- ✅ Shows notifications on completion
- ✅ Can be distributed as a single .app file

## Prerequisites (One-Time Setup)

### 1. Install PyInstaller

```bash
pip3 install pyinstaller
```

### 2. Install Platypus

```bash
brew install platypus
```

Or download from: https://sveinbjorn.org/platypus

## Build the App (2 Minutes)

### Step 1: Run the Build Script

```bash
cd /Users/dmitriy/www/AA/docx-html
./build-app.sh
```

The script will:
- Check dependencies
- Clean old builds
- Build standalone executable (~2 minutes)
- Create macOS app bundle
- Show you where everything is

### Step 2: Test the App

```bash
open dist/DOCX2HTML.app
```

Drag a .docx file onto the window that appears.

### Step 3: Check the Output

The HTML file will be created in the same directory as your .docx file.

## Using the App

### For You (Developer)

The app is located at:
```
/Users/dmitriy/www/AA/docx-html/dist/DOCX2HTML.app
```

You can:
- Copy it to your Applications folder
- Use it directly from the dist folder
- Drag .docx files onto the app icon
- Drop .docx files into the app window

### Configuration

Edit your conversion settings:
```bash
open ~/Library/Application\ Support/DOCX2HTML/config.json
```

Changes take effect immediately on the next conversion.

### For End Users (Distribution)

1. **Package for distribution:**
   ```bash
   cd dist
   zip -r DOCX2HTML.zip DOCX2HTML.app
   ```

2. **Share the zip file** with your users

3. **User installation:**
   - Unzip the file
   - Drag DOCX2HTML.app to Applications
   - Right-click > Open (first time only, to bypass Gatekeeper)
   - Drop .docx files to convert

## Configuration Location

### Development (you)
- Uses: `/Users/dmitriy/www/AA/docx-html/config.json` (if it exists)
- Falls back to: `~/Library/Application Support/DOCX2HTML/config.json`

### End Users
- Uses: `~/Library/Application Support/DOCX2HTML/config.json`
- Created automatically on first run with defaults
- Can be edited with any text editor

## Customizing the Config

Users can customize by editing `~/Library/Application Support/DOCX2HTML/config.json`:

```json
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
    }
  ],
  "replacements": [
    {
      "search": "@AmericanAir",
      "replace": "<a href='https://aa.com'>@AmericanAir</a>",
      "case_sensitive": true
    }
  ]
}
```

## Rebuilding After Changes

If you modify the Python code:

```bash
./build-app.sh
```

That's it! The new app will be in `dist/DOCX2HTML.app`.

## Troubleshooting

### PyInstaller not found
```bash
pip3 install pyinstaller
```

### Platypus not found
```bash
brew install platypus
```

### App won't open (macOS Security)
Right-click the app > Open > Click "Open" in the dialog

### Config not being created
Run the app at least once - it creates the config on first run

### Want to see what's happening?
The app shows output in a text window when you drop files.

## File Sizes

- Standalone executable: ~40-60 MB
- Complete app bundle: ~50-80 MB
- Zipped for distribution: ~30-40 MB

This is normal - it includes Python runtime and all libraries.

## Next Steps

- Read [PACKAGING.md](PACKAGING.md) for advanced options
- Read [README.md](README.md) for all features
- Customize your [config.json](config.json) for default settings

## Need Help?

1. Check the build output for errors
2. Test the standalone executable: `./dist/docx2html --help`
3. Look at the Platypus app output when dropping files
4. Verify config file exists: `ls ~/Library/Application\ Support/DOCX2HTML/`

## Summary

```bash
# One-time setup
pip3 install pyinstaller
brew install platypus

# Build
./build-app.sh

# Test
open dist/DOCX2HTML.app
# (drag a .docx file to test)

# Distribute
cd dist && zip -r DOCX2HTML.zip DOCX2HTML.app
```

Done! 🎉
