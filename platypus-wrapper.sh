#!/bin/bash
#
# Platypus wrapper script for DOCX2HTML converter
# This script provides a dropzone interface for converting DOCX files to HTML
#

# Get the directory where the app bundle is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Path to the PyInstaller-built executable
# When Platypus bundles this, the executable will be in the app's Resources folder
if [ -f "$SCRIPT_DIR/docx2html" ]; then
    CONVERTER="$SCRIPT_DIR/docx2html"
elif [ -f "$SCRIPT_DIR/../Resources/docx2html" ]; then
    CONVERTER="$SCRIPT_DIR/../Resources/docx2html"
else
    # Fallback to system path
    CONVERTER="docx2html"
fi

# Configuration file location
CONFIG_DIR="$HOME/Library/Application Support/DOCX2HTML"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Process each dropped file
for file in "$@"; do
    if [[ "$file" == *.docx ]]; then
        echo "Converting: $(basename "$file")"

        # Get output filename (same name, different extension)
        output_file="${file%.docx}.html"

        # Run the converter
        "$CONVERTER" "$file" -o "$output_file"

        if [ $? -eq 0 ]; then
            echo "✓ Converted successfully: $(basename "$output_file")"

            # Show macOS notification
            osascript -e "display notification \"Converted to $(basename "$output_file")\" with title \"DOCX2HTML\" subtitle \"Success\""
        else
            echo "✗ Error converting: $(basename "$file")"

            # Show error notification
            osascript -e "display notification \"Failed to convert $(basename "$file")\" with title \"DOCX2HTML\" subtitle \"Error\""
        fi
    else
        echo "Skipping non-DOCX file: $(basename "$file")"
        osascript -e "display notification \"Only .docx files are supported\" with title \"DOCX2HTML\" subtitle \"Skipped: $(basename "$file")\""
    fi
done

# Show config location on first run
if [ ! -f "$CONFIG_FILE" ]; then
    osascript -e "display notification \"Configuration created at: $CONFIG_FILE\" with title \"DOCX2HTML\" subtitle \"First Run\""
fi

echo ""
echo "============================================"
echo "DOCX2HTML Converter"
echo "============================================"
echo ""
echo "Drop a .docx file here to start conversion."
echo ""
echo "Configuration: $CONFIG_FILE"
echo "============================================"
