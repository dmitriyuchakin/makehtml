# makeHTML

A native macOS application for converting Microsoft Word (.docx) files to clean, formatted HTML.

## Features

- 🚀 **Fast conversion** - Drag and drop .docx files for instant HTML output
- 🎨 **Clean HTML** - Produces semantic, well-formatted HTML
- 📝 **Live preview** - See your HTML rendered in real-time
- 🔧 **Customizable** - Configure output via `config.json`
- 🎯 **Heading detection** - Automatically detects and formats headings
- 📋 **Code snippets** - Add custom HTML snippets to your output
- 🔄 **Auto-updates** - Stay up to date with Sparkle framework

## Installation

### From Release

1. Download the latest `makeHTML.zip` from [Releases](https://github.com/yourusername/makehtml/releases)
2. Extract and move `makeHTML.app` to `/Applications`
3. Open the app and drag a .docx file to convert

### Build from Source

```bash
git clone https://github.com/yourusername/makehtml.git
cd makehtml/makeHTML-Swift
./build.sh
open build/makeHTML.app
```

## Usage

1. **Drag and drop** a .docx file onto the app window
2. **Preview** the HTML output in the built-in viewer
3. Click **"Open HTML"** to edit in your preferred editor
4. HTML file is saved next to your original .docx file

## Configuration

Edit settings at: `~/Library/Application Support/makeHTML/config.json`

- Heading detection
- Quote detection
- Link handling
- HTML formatting options
- Custom code snippets

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel Mac

## Third-Party Software

makeHTML includes the following open-source components:

- **[HTML Tidy](https://www.html-tidy.org/)** - HTML formatting and cleaning (W3C License)
- **[Sparkle](https://sparkle-project.org/)** - Automatic software updates (MIT License)

See [LICENSES.md](LICENSES.md) for full license text.

## License

[Choose your license: MIT, Apache 2.0, GPL-3.0, etc.]

## Credits

Created by [Your Name]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

Report bugs and request features: [dmitriy@uchakin.com](mailto:dmitriy@uchakin.com)
