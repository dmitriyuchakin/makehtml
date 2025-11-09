# DOCX to HTML Converter

A Python-based command-line tool for converting Microsoft Word (.docx) files to clean, customizable HTML.

## Features

- Clean HTML output without inline styles
- Configurable paragraph and heading tags
- Automatic bullet and numbered list conversion to `<ul><li>` and `<ol><li>` tags
- Full support for nested/indented lists at any depth
- Automatic table conversion with proper `<thead>` and `<tbody>` structure
- Flexible special character wrapping (©, ®, ™, or any custom character) with configurable HTML tags
- Automatic hyperlink conversion to `<a href="">` tags
- Custom search and replace rules via JSON configuration
- Preserves basic text formatting (bold, italic, underline)
- Easy to integrate with macOS Automator

## Installation

### 1. Install Python Dependencies

```bash
pip3 install -r requirements.txt
```

Or install manually:

```bash
pip3 install python-docx lxml
```

### 2. Make the Script Executable

```bash
chmod +x docx2html.py
```

## Usage

### Basic Usage

Convert a DOCX file to HTML:

```bash
python3 docx2html.py input.docx
```

This will create `input.html` in the same directory.

### Specify Output File

```bash
python3 docx2html.py input.docx -o output.html
```

### Use Custom Configuration

```bash
python3 docx2html.py input.docx -c custom-config.json
```

### Command-Line Options

- `input` - Path to the input DOCX file (required)
- `-o, --output` - Path to the output HTML file (optional, defaults to same name as input with .html extension)
- `-c, --config` - Path to custom configuration JSON file (optional, defaults to config.json in script directory)

## Configuration

The converter uses a JSON configuration file ([config.json](config.json)) to control the conversion process.

### Default Configuration

```json
{
  "output": {
    "clean_html": true,
    "include_styles": false,
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
      "search": "oneworld",
      "replace": "<strong>one</strong>world",
      "case_sensitive": true
    }
  ]
}
```

### Configuration Options

#### Output Settings

- `clean_html` - Generate clean HTML without inline styles (default: `true`)
- `include_styles` - Include styles from the DOCX file (default: `false`)
- `paragraph_tag` - HTML tag to use for paragraphs (default: `"p"`)
- `heading_tag` - HTML tag to use for all headings (default: `"h3"`)

#### Special Characters

Configure any special characters to be automatically wrapped in HTML tags. Each entry supports:

- `character` - The actual character to wrap (e.g., `"©"`, `"®"`, `"™"`)
- `wrap_tag` - HTML tag to wrap the character in (default: `"sup"`)
- `enabled` - Whether to apply this transformation (default: `true`)

You can add any character you want to wrap by simply adding a new entry to the array. For example:

```json
{
  "special_characters": [
    {
      "character": "©",
      "wrap_tag": "sup",
      "enabled": true
    },
    {
      "character": "§",
      "wrap_tag": "span",
      "enabled": true
    }
  ]
}
```

#### Custom Replacements

Add search and replace rules to transform specific strings:

```json
{
  "replacements": [
    {
      "search": "text to find",
      "replace": "replacement text",
      "case_sensitive": true
    }
  ]
}
```

- `search` - Text to search for
- `replace` - Replacement text (can include HTML tags)
- `case_sensitive` - Whether the search is case-sensitive (default: `true`)

### Example Replacements

```json
{
  "replacements": [
    {
      "search": "oneworld",
      "replace": "<strong>one</strong>world",
      "case_sensitive": true
    },
    {
      "search": "IMPORTANT",
      "replace": "<span class=\"important\">IMPORTANT</span>",
      "case_sensitive": false
    },
    {
      "search": "TM",
      "replace": "<sup>TM</sup>",
      "case_sensitive": true
    }
  ]
}
```

## HTML Output

### Paragraphs

All paragraphs are wrapped in `<p>` tags (configurable):

```html
<p>This is a paragraph.</p>
```

### Headings

All headings are converted to `<h3>` tags (configurable):

```html
<h3>This is a heading</h3>
```

### Lists

Bullet points and numbered lists are automatically converted to proper HTML lists with full support for nested/indented lists:

**Bulleted lists:**
```html
<ul>
  <li>First item</li>
  <li>Second item</li>
  <li>Third item</li>
</ul>
```

**Numbered lists:**
```html
<ol>
  <li>First item</li>
  <li>Second item</li>
  <li>Third item</li>
</ol>
```

**Nested lists:**
```html
<ul>
  <li>First item
    <ul>
      <li>Nested item 1</li>
      <li>Nested item 2</li>
    </ul>
  </li>
  <li>Second item</li>
</ul>
```

The converter automatically detects indentation levels in your DOCX file and creates properly nested `<ul>` and `<ol>` structures.

### Tables

Tables are converted to proper HTML tables with `<thead>` and `<tbody>`:

```html
<table>
  <thead>
    <tr>
      <th>Header 1</th>
      <th>Header 2</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Cell 1</td>
      <td>Cell 2</td>
    </tr>
  </tbody>
</table>
```

### Text Formatting

Basic text formatting is preserved:

- **Bold text** → `<strong>bold text</strong>`
- *Italic text* → `<em>italic text</em>`
- Underlined text → `<u>underlined text</u>`

### Hyperlinks

Hyperlinks from your DOCX document are automatically converted to HTML anchor tags:

```html
<a href="https://example.com">Click here</a>
```

The converter:
- Preserves the original URL from the DOCX file
- Maintains the link text
- Works with both external URLs and internal document references
- Preserves formatting (bold, italic) within the link text

### Special Symbols

Special symbols are automatically wrapped in configurable HTML tags. By default, copyright, registered trademark, and trademark symbols are wrapped in `<sup>` tags:

**Copyright symbol:**
```html
<sup>©</sup>
```

**Registered trademark symbol:**
```html
<sup>®</sup>
```

**Trademark symbol:**
```html
<sup>™</sup>
```

You can customize which symbols to wrap and what tag to use by editing the `special_characters` array in [config.json](config.json).

## macOS Automator Integration

You can easily create a macOS Automator Quick Action to convert DOCX files from Finder.

### Step 1: Create a Quick Action

1. Open **Automator** (in Applications or use Spotlight)
2. Choose **Quick Action** (or "Service" in older macOS versions)
3. Configure the workflow:
   - "Workflow receives current" → **files or folders**
   - "in" → **Finder**

### Step 2: Add Run Shell Script Action

1. Search for "Run Shell Script" in the actions library
2. Drag it to the workflow area
3. Configure:
   - "Shell" → **/bin/bash**
   - "Pass input" → **as arguments**

### Step 3: Add the Script

Paste the following script:

```bash
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

for f in "$@"
do
    if [[ "$f" == *.docx ]]; then
        # Get the directory of this script or use full path
        SCRIPT_DIR="/Users/dmitriy/www/AA/docx-html"

        # Run the converter
        /usr/bin/python3 "$SCRIPT_DIR/docx2html.py" "$f"

        # Optional: Show notification
        osascript -e "display notification \"Converted $(basename "$f")\" with title \"DOCX to HTML\""
    fi
done
```

**Important:** Replace `/Users/dmitriy/www/AA/docx-html` with the actual path where you saved the script.

### Step 4: Save the Quick Action

1. Save the Quick Action with a name like "Convert DOCX to HTML"
2. Close Automator

### Step 5: Use It

1. In Finder, right-click on any .docx file
2. Go to **Quick Actions** (or **Services**)
3. Select "Convert DOCX to HTML"
4. The HTML file will be created in the same directory

### Alternative: Folder Action

You can also create a Folder Action that automatically converts any DOCX file dropped into a specific folder:

1. Open Automator and create a new **Folder Action**
2. Choose the folder to monitor
3. Add the same "Run Shell Script" action with the script above
4. Save the action

Now any DOCX file dropped into that folder will be automatically converted to HTML.

## Troubleshooting

### Python Not Found

If you get a "python3: command not found" error, install Python from [python.org](https://www.python.org/downloads/) or use Homebrew:

```bash
brew install python3
```

### Dependencies Not Found

Make sure to install the required packages:

```bash
pip3 install python-docx lxml
```

### Permission Denied

Make the script executable:

```bash
chmod +x docx2html.py
```

### Automator Can't Find Python

In the Automator script, use the full path to Python:

```bash
/usr/bin/python3 /full/path/to/docx2html.py "$f"
```

Or if you installed Python via Homebrew:

```bash
/opt/homebrew/bin/python3 /full/path/to/docx2html.py "$f"
```

## Examples

### Convert with Default Settings

```bash
python3 docx2html.py mydocument.docx
```

### Convert with Custom Output Location

```bash
python3 docx2html.py mydocument.docx -o /path/to/output.html
```

### Convert with Custom Configuration

```bash
python3 docx2html.py mydocument.docx -c myconfig.json
```

## Packaging as macOS App

You can package this tool as a standalone macOS application with a dropzone interface that requires no Python installation.

### Quick Build

```bash
./build-app.sh
```

This creates:
- `dist/docx2html` - Standalone command-line executable
- Ready for Platypus app creation

### Requirements

- PyInstaller: `pip3 install pyinstaller`
- Platypus: `brew install platypus`

### Interface Options

You can create the app with two different interfaces:

**1. Text Window** (Simple)
- Console-style text output
- Lightweight and fast
- Best for batch processing
- Uses: `platypus-wrapper.sh`

**2. WebView** (Preview)
- Shows rendered HTML preview
- Professional styled interface
- Visual feedback with conversion results
- Uses: `platypus-wrapper-webview.sh`

Both save the HTML file to disk and use the same conversion engine - only the UI differs.

### Features

The packaged app provides:
- Drag & drop interface for .docx files
- No Python installation required for end users
- Automatic config file management at `~/Library/Application Support/DOCX2HTML/config.json`
- macOS notifications on completion
- ~50-80MB standalone bundle with all dependencies
- **WebView**: HTML preview with styled results page
- **Text Window**: Simple, fast text-based feedback

### Distribution

After building, you can distribute `dist/DOCX2HTML.app` to users. They simply:
1. Copy the app to their Applications folder
2. Drop .docx files onto the app
3. Get HTML files in the same directory
4. (WebView only) See immediate preview of conversion results

For detailed packaging instructions and interface comparisons, see [PLATYPUS-GUI-GUIDE.md](PLATYPUS-GUI-GUIDE.md).

## License

This project is open source and available for use.
