#!/bin/bash
#
# Automated build script for makeHTML macOS app
# This script builds the complete application using PyInstaller
#

set -e  # Exit on error

echo "========================================"
echo "makeHTML macOS App Builder"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check if PyInstaller is installed
echo -e "${YELLOW}[1/5]${NC} Checking dependencies..."
if ! command -v pyinstaller &> /dev/null; then
    echo -e "${YELLOW}!${NC} PyInstaller not in PATH. Installing/checking..."
    pip3 install --user pyinstaller

    # Add common Python user bin directories to PATH
    export PATH="$HOME/Library/Python/3.9/bin:$PATH"
    export PATH="$HOME/.local/bin:$PATH"

    if command -v pyinstaller &> /dev/null; then
        echo -e "${GREEN}✓${NC} PyInstaller is now available"
    else
        echo -e "${RED}✗${NC} Could not find pyinstaller. Trying with python3 -m PyInstaller..."
    fi
else
    echo -e "${GREEN}✓${NC} PyInstaller is installed"
fi

# Check if Platypus CLI is available
if ! command -v platypus &> /dev/null; then
    echo -e "${YELLOW}!${NC} Platypus CLI not found."
    echo "  Install Platypus from: https://sveinbjorn.org/platypus"
    echo "  Or run: brew install platypus"
    echo ""
    echo "  This script will build the PyInstaller executable."
    echo "  You'll need to use Platypus GUI manually for the final app."
    PLATYPUS_AVAILABLE=false
else
    echo -e "${GREEN}✓${NC} Platypus is installed"
    PLATYPUS_AVAILABLE=true
fi

echo ""

# Step 2: Clean previous builds
echo -e "${YELLOW}[2/5]${NC} Cleaning previous builds..."
rm -rf build dist
rm -f makehtml.spec
echo -e "${GREEN}✓${NC} Cleaned build directories"
echo ""

# Step 3: Build with PyInstaller
echo -e "${YELLOW}[3/5]${NC} Building standalone executable with PyInstaller..."
echo "  This may take a few minutes..."

# Try to use pyinstaller, fall back to python3 -m PyInstaller
if command -v pyinstaller &> /dev/null; then
    PYINSTALLER_CMD="pyinstaller"
else
    PYINSTALLER_CMD="python3 -m PyInstaller"
    echo "  Using: python3 -m PyInstaller"
fi

$PYINSTALLER_CMD --name makehtml \
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
    makehtml.py

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} PyInstaller build successful"
    echo -e "  Executable created at: ${GREEN}dist/makehtml${NC}"
else
    echo -e "${RED}✗${NC} PyInstaller build failed"
    exit 1
fi
echo ""

# Step 4: Test the executable
echo -e "${YELLOW}[4/5]${NC} Testing executable..."
if [ -f "dist/makehtml" ]; then
    ./dist/makehtml --help > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Executable works correctly"
    else
        echo -e "${YELLOW}!${NC} Executable may have issues (test manually)"
    fi
else
    echo -e "${RED}✗${NC} Executable not found"
    exit 1
fi
echo ""

# Step 5: Done (Platypus removed, using Swift app instead)
echo -e "${YELLOW}[5/5]${NC} Python executable complete"
echo ""
echo -e "${GREEN}✓${NC} Python converter ready"
echo "  Next step: Build the Swift app with:"
echo "  cd makeHTML-Swift && ./build.sh"

echo ""
echo "========================================"
echo -e "${GREEN}Build Complete!${NC}"
echo "========================================"
echo ""
echo "Output files:"
echo "  • Standalone executable: dist/makehtml"
echo ""
echo "Configuration file location:"
echo "  ~/Library/Application Support/makeHTML/config.json"
echo ""
echo "The app will create the config file on first run."
echo "Users can edit it with any text editor to customize conversion."
echo ""
