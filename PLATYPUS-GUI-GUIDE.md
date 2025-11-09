# Creating DOCX2HTML.app with Platypus GUI

Since you already have the standalone executable built at `dist/docx2html`, here's how to complete the app using Platypus GUI (which is already installed).

## Choose Your Interface

You have two interface options:

1. **Text Window** (Simple) - Shows console-style text output
   - Lightweight and straightforward
   - Best for quick batch conversions
   - Uses: `platypus-wrapper.sh`

2. **WebView** (Preview) - Shows HTML preview with styled results
   - Visual preview of converted HTML
   - Professional appearance
   - Shows actual rendered output
   - Uses: `platypus-wrapper-webview.sh`

Choose the option that best fits your workflow. Instructions below cover both.

---

## Option 1: Text Window Interface (Simple)

### 1. Open Platypus

```bash
open /Applications/Platypus.app
```

### 2. Configure Basic Settings

In the Platypus window:

**App Name:** `DOCX2HTML`

**Script Type:** Select `/bin/bash` from dropdown

**Script Path:** Click "Select..." and choose:
```
/Users/dmitriy/www/AA/docx-html/platypus-wrapper.sh
```

**Interface:** Select `Text Window` from dropdown

**Identifier:** `com.docx2html.converter`

**Author:** Your name (e.g., "Dmitriy")

**Version:** `1.0.0`

### 3. Configure Dropzone Settings

Click the **"Settings"** tab and check:

- ☑ **Accept dropped items**
- ☑ **Accept dropped files**
- **Document types:** Add `docx` (click the + button, type "docx", press Enter)

### 4. Add Bundled Files

Click the **"Bundled Files"** tab:

1. Click the **"+"** button at the bottom
2. Navigate to and select: `/Users/dmitriy/www/AA/docx-html/dist/docx2html`
3. Click "Open"

You should see `docx2html` in the bundled files list.

### 5. Create the App

1. Click **"Create App"** button at the bottom right
2. Choose where to save (suggest: `/Users/dmitriy/www/AA/docx-html/dist/`)
3. Name it: `DOCX2HTML`
4. Click "Create"

### 6. Test It!

```bash
open dist/DOCX2HTML.app
```

Drag a .docx file onto the window that appears!

## Visual Checklist

When you're done, your Platypus settings should look like:

```
┌─ Platypus ────────────────────────────────┐
│                                            │
│ App Name:      DOCX2HTML                   │
│ Script Type:   /bin/bash                   │
│ Script Path:   .../platypus-wrapper.sh     │
│ Interface:     Text Window                 │
│ Identifier:    com.docx2html.converter     │
│ Author:        Dmitriy                     │
│ Version:       1.0.0                       │
│                                            │
│ ☑ Accept dropped items                     │
│ ☑ Accept dropped files                     │
│ Document types: docx                       │
│                                            │
│ Bundled Files:                             │
│   • docx2html                              │
│                                            │
│                    [Create App]            │
└────────────────────────────────────────────┘
```

## What You'll Get

After clicking "Create App", you'll have:

- **dist/DOCX2HTML.app** - Complete, standalone macOS app
- Size: ~10-15 MB (very small!)
- No Python required for end users
- Drag & drop interface
- macOS notifications on completion

## Distribution

To share with others:

```bash
cd dist
zip -r DOCX2HTML.zip DOCX2HTML.app
```

Send them the zip file. They just:
1. Unzip
2. Drag to Applications
3. Right-click > Open (first time only)
4. Drop .docx files to convert!

## Troubleshooting

### Can't find Platypus?
```bash
open /Applications/Platypus.app
```

### Can't find the executable?
Make sure you ran `./build-app.sh` first to create `dist/docx2html`

### App won't accept dropped files?
Double-check in Platypus Settings tab:
- "Accept dropped files" is checked
- "docx" is in Document types list

### Want to change settings later?
1. Open Platypus
2. File > Open > Select your DOCX2HTML.app
3. Make changes
4. Create App again (overwrites old one)

## Done!

Once you've created the app, you can:
- Use it yourself by dropping files onto it
- Share it with colleagues
- Customize by editing `~/Library/Application Support/DOCX2HTML/config.json`

The config file will be created automatically the first time someone uses the app!

---

## Option 2: WebView Interface (Preview)

This version shows a beautiful HTML preview of your converted documents!

### 1. Open Platypus

```bash
open /Applications/Platypus.app
```

### 2. Configure Basic Settings

In the Platypus window:

**App Name:** `DOCX2HTML`

**Script Type:** Select `/bin/bash` from dropdown

**Script Path:** Click "Select..." and choose:
```
/Users/dmitriy/www/AA/docx-html/platypus-wrapper-webview.sh
```

**Interface:** Select `Web View` from dropdown ⭐

**Identifier:** `com.docx2html.converter`

**Author:** Your name (e.g., "Dmitriy")

**Version:** `1.0.0`

### 3. Configure Dropzone Settings

Click the **"Settings"** tab and check:

- ☑ **Accept dropped items**
- ☑ **Accept dropped files**
- **Document types:** Add `docx` (click the + button, type "docx", press Enter)

### 4. Add Bundled Files

Click the **"Bundled Files"** tab:

1. Click the **"+"** button at the bottom
2. Navigate to and select: `/Users/dmitriy/www/AA/docx-html/dist/docx2html`
3. Click "Open"

You should see `docx2html` in the bundled files list.

### 5. Create the App

1. Click **"Create App"** button at the bottom right
2. Choose where to save (suggest: `/Users/dmitriy/www/AA/docx-html/dist/`)
3. Name it: `DOCX2HTML` (or `DOCX2HTML-WebView` to distinguish from Text Window version)
4. Click "Create"

### 6. Test It!

```bash
open dist/DOCX2HTML.app
```

You'll see a styled dropzone. Drag a .docx file and watch the magic happen!

## WebView Features

The WebView interface provides:

- **Styled Dropzone**: Beautiful initial screen with instructions
- **Success Page**: Shows conversion results with:
  - ✓ Success indicator
  - Input/output file names
  - Clickable link to open the HTML file
  - Full preview of the converted HTML content
- **Error Handling**: Styled error messages if conversion fails
- **Professional Appearance**: Uses macOS system fonts and design patterns

### What You'll See

**Before Dropping:**
```
┌─────────────────────────────────┐
│     📄 DOCX2HTML                │
│                                 │
│  Drop a .docx file here to      │
│  convert it to HTML             │
│                                 │
│  Your converted HTML will be    │
│  saved in the same directory    │
└─────────────────────────────────┘
```

**After Conversion:**
```
┌─────────────────────────────────┐
│  ✓ Conversion Complete SUCCESS  │
├─────────────────────────────────┤
│ Input File:  document.docx      │
│ Output File: document.html 🔗   │
│ Location:    /path/to/file      │
├─────────────────────────────────┤
│        HTML Preview             │
│ ┌─────────────────────────────┐ │
│ │ [Your converted HTML        │ │
│ │  rendered beautifully with  │ │
│ │  all formatting preserved]  │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

## Comparison: Text Window vs WebView

| Feature | Text Window | WebView |
|---------|-------------|---------|
| **Output Style** | Plain text console | Styled HTML page |
| **Preview** | No preview | Shows rendered HTML |
| **File Size** | Smaller (~10-15 MB) | Slightly larger (~15-20 MB) |
| **Speed** | Faster startup | Slightly slower (WebKit) |
| **Use Case** | Quick batch processing | Visual verification |
| **Appearance** | Simple, functional | Professional, polished |

**Choose Text Window if:**
- You want fastest performance
- You don't need to see previews
- You prefer minimal interfaces

**Choose WebView if:**
- You want to see conversion results immediately
- You're presenting to clients/stakeholders
- You want a more polished UX

Both versions save the HTML file to disk and use the same conversion engine - the only difference is the user interface!
