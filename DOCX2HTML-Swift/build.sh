#!/bin/bash
#
# Build script for DOCX2HTML native macOS app
#

set -e

echo "========================================="
echo "Building DOCX2HTML Native macOS App"
echo "========================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    echo "Please install with: xcode-select --install"
    exit 1
fi

# Check if converter exists
CONVERTER_PATH="../dist/docx2html"
if [ ! -f "$CONVERTER_PATH" ]; then
    echo "Error: Converter not found at $CONVERTER_PATH"
    echo "Please run ../build-app.sh first to create the Python executable"
    exit 1
fi

echo ""
echo "[1/4] Creating Xcode project..."

# Create a temporary Xcode project directory
PROJECT_DIR="DOCX2HTML.xcodeproj"
mkdir -p "$PROJECT_DIR"

# We'll use swift build instead for simplicity
# Create Package.swift for SwiftPM
cat > Package.swift << 'EOF'
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DOCX2HTML",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DOCX2HTML",
            dependencies: [],
            path: "."
        )
    ]
)
EOF

echo "✓ Project files created"

echo ""
echo "[2/4] Building Swift app..."

# Build the app using swiftc directly for a simple app bundle
APP_NAME="DOCX2HTML"
APP_BUNDLE="build/${APP_NAME}.app"
APP_MACOS="${APP_BUNDLE}/Contents/MacOS"
APP_RESOURCES="${APP_BUNDLE}/Contents/Resources"

# Clean and create directories
rm -rf build
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Compile the Swift code
swiftc -o "${APP_MACOS}/${APP_NAME}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework UniformTypeIdentifiers \
    DOCX2HTMLApp.swift \
    ContentView.swift

echo "✓ Swift compilation complete"

echo ""
echo "[3/4] Bundling resources..."

# Copy the Python converter
cp "$CONVERTER_PATH" "$APP_RESOURCES/docx2html"
chmod +x "$APP_RESOURCES/docx2html"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DOCX2HTML</string>
    <key>CFBundleIdentifier</key>
    <string>com.docx2html.converter</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DOCX2HTML</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
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
