#!/bin/bash
#
# Build script for makeHTML native macOS app
#

set -e

# Version configuration
APP_VERSION="0.5"
BUILD_NUMBER="1111"

echo "========================================="
echo "Building makeHTML Native macOS App"
echo "Version: $APP_VERSION (Build $BUILD_NUMBER)"
echo "========================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    echo "Please install with: xcode-select --install"
    exit 1
fi

# No Python converter needed anymore - using native Swift!

echo ""
echo "[1/4] Preparing tidy binary..."

# Check if tidy is installed and copy it for bundling
TIDY_SOURCE="/opt/homebrew/bin/tidy"
if [ ! -f "$TIDY_SOURCE" ]; then
    TIDY_SOURCE="/usr/local/bin/tidy"
fi

if [ ! -f "$TIDY_SOURCE" ]; then
    TIDY_SOURCE="/usr/bin/tidy"
fi

if [ -f "$TIDY_SOURCE" ]; then
    echo "  Found tidy at: $TIDY_SOURCE"
    TIDY_TEMP="./tidy-binary"
    cp "$TIDY_SOURCE" "$TIDY_TEMP"
    echo "✓ Tidy binary ready for bundling"
else
    echo "⚠ Warning: tidy not found. HTML formatting will be skipped."
    TIDY_TEMP=""
fi

echo ""
echo "[2/4] Building Swift app..."

# Build the app using swiftc directly
APP_NAME="makeHTML"
APP_BUNDLE="build/${APP_NAME}.app"
APP_MACOS="${APP_BUNDLE}/Contents/MacOS"
APP_RESOURCES="${APP_BUNDLE}/Contents/Resources"

# Clean and create directories
rm -rf build
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Compile the Swift code
swiftc -o "${APP_MACOS}/${APP_NAME}" \
    -target arm64-apple-macosx14.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework UniformTypeIdentifiers \
    -framework WebKit \
    makeHTMLApp.swift \
    ContentView.swift \
    DocxXMLParser.swift \
    DocxConverter.swift \
    ConversionLogger.swift

echo "✓ Swift compilation complete"

echo ""
echo "[3/4] Bundling resources..."

# Copy header images
if [ -f "header-icon-light-600.png" ]; then
    cp "header-icon-light-600.png" "$APP_RESOURCES/"
fi
if [ -f "header-icon-dark-600.png" ]; then
    cp "header-icon-dark-600.png" "$APP_RESOURCES/"
fi

# Copy config.json template
if [ -f "config.json" ]; then
    cp "config.json" "$APP_RESOURCES/config.json"
fi

# Copy preview.css template
if [ -f "preview.css" ]; then
    cp "preview.css" "$APP_RESOURCES/preview.css"
fi

# Copy snippet files
if [ -d "snippets" ]; then
    echo "  Copying snippet files..."
    mkdir -p "$APP_RESOURCES/snippets"
    cp snippets/*.html "$APP_RESOURCES/snippets/" 2>/dev/null || true
    echo "  ✓ Snippets bundled"
fi

# Copy tidy binary if available
if [ -n "$TIDY_TEMP" ] && [ -f "$TIDY_TEMP" ]; then
    echo "  Bundling tidy binary..."
    cp "$TIDY_TEMP" "$APP_RESOURCES/tidy"
    chmod +x "$APP_RESOURCES/tidy"
    rm "$TIDY_TEMP"
    echo "  ✓ Tidy binary bundled (835KB)"
fi

# Create app icon from PNG
if [ -f "makeHTML-icon.png" ]; then
    echo "  Creating app icon..."

    # Create iconset directory
    ICONSET_DIR="makeHTML.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    # Generate different icon sizes using sips
    sips -z 16 16     "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 "makeHTML-icon.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null 2>&1

    # Convert to icns
    iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES/makeHTML.icns" > /dev/null 2>&1

    # Clean up
    rm -rf "$ICONSET_DIR"

    echo "  ✓ App icon created"
fi

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>makeHTML</string>
    <key>CFBundleIdentifier</key>
    <string>com.makehtml.converter</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>makeHTML</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleIconFile</key>
    <string>makeHTML.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>docx</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Microsoft Word Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "✓ Resources bundled"

echo ""
echo "[4/4] Code signing..."

# Simple ad-hoc code signing
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✓ App signed"

echo ""
echo "========================================="
echo "✓ Build Complete!"
echo "========================================="
echo ""
echo "App location: ${APP_BUNDLE}"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
