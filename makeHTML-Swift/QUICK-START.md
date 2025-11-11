# Quick Start Guide

## Accept Xcode License (One-Time Setup)

Before building, you need to accept the Xcode license:

```bash
sudo xcodebuild -license
```

Press 'q' to skip to the end, then type 'agree'

## Build the App

```bash
cd /Users/dmitriy/www/AA/docx-html/DOCX2HTML-Swift
./build.sh
```

## Alternative: Use Xcode IDE

If the command-line build doesn't work, you can use Xcode:

1. Open Xcode
2. Create new macOS App project:
   - Product Name: DOCX2HTML
   - Interface: SwiftUI
   - Language: Swift
   - Minimum macOS: 13.0

3. Replace the generated files:
   - Delete `ContentView.swift` and `DOCX2HTMLApp.swift`
   - Drag the files from this folder into Xcode

4. Add the converter to your project:
   - Right-click on project → Add Files
   - Select `../dist/docx2html`
   - Make sure "Copy items if needed" is checked
   - Target Membership: checked

5. Build and run (Cmd+R)

## Test It

After building, drop a .docx file on the app window and verify:
- ✅ File converts successfully
- ✅ HTML preview appears
- ✅ "Open Config Folder" button opens Finder
- ✅ "Edit in VS Code" button opens the config file

All buttons should work perfectly without any navigation issues!
