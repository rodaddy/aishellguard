#!/usr/bin/env zsh
# bundle.sh - Create macOS .app bundle for AIShellGuard
#
# Usage: ./scripts/bundle.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AIShellGuard"
BUNDLE_ID="com.aishellguard.app"
VERSION="0.5.0"

BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "========================================="
echo "Building $APP_NAME.app bundle"
echo "========================================="

# Clean up old bundle if it exists
if [[ -d "$APP_BUNDLE" ]]; then
    echo "Removing old bundle..."
    rm -rf "$APP_BUNDLE"
fi

# Step 1: Build with Swift Package Manager
echo ""
echo "Step 1: Building release binary..."
cd "$PROJECT_ROOT"
swift build -c release
echo "✓ Build complete"

# Step 2: Create bundle structure
echo ""
echo "Step 2: Creating .app bundle structure..."
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
echo "✓ Bundle structure created"

# Step 3: Copy binary
echo ""
echo "Step 3: Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"
echo "✓ Binary copied"

# Step 4: Copy SPM resource bundle
echo ""
echo "Step 4: Copying SPM resource bundle..."
RESOURCE_BUNDLE="$BUILD_DIR/AIShellGuard_AIShellGuard.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
    echo "✓ Resource bundle copied"
else
    echo "⚠ Warning: Resource bundle not found at $RESOURCE_BUNDLE"
fi

# Step 5: Generate AppIcon.icns
echo ""
echo "Step 5: Generating AppIcon.icns..."
ICON_SOURCE="$PROJECT_ROOT/SSHGuard/Resources/AppIcon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "⚠ Warning: AppIcon.png not found, skipping icon generation"
else
    # Create iconset directory
    mkdir -p "$ICONSET_DIR"

    # Generate all required icon sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

    # Convert iconset to icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns"

    # Clean up iconset
    rm -rf "$ICONSET_DIR"

    echo "✓ AppIcon.icns generated"
fi

# Step 6: Generate Info.plist
echo ""
echo "Step 6: Generating Info.plist..."
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>AIShell Guard</string>
    <key>CFBundleDisplayName</key>
    <string>AIShell Guard</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
echo "✓ Info.plist generated"

# Step 7: Ad-hoc code sign
echo ""
echo "Step 7: Code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"
echo "✓ Code signed"

echo ""
echo "========================================="
echo "Bundle creation complete!"
echo "========================================="
echo ""
echo "Output: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  ./scripts/install.sh"
echo ""
echo "To run directly:"
echo "  open $APP_BUNDLE"
echo ""
