#!/bin/bash
# install.sh - Install SSHGuard menu bar app and hooks
#
# Usage: ./scripts/install.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AIShellGuard"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "AIShell Guard Installation"
echo "========================================="

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠ jq is required but not installed${NC}"
    echo "Installing jq via Homebrew..."
    brew install jq
fi

# Build the app
echo ""
echo "Step 1: Building $APP_NAME..."
cd "$PROJECT_ROOT"

swift build -c release
echo -e "${GREEN}✓${NC} Build complete (Swift PM)"

# Install hook
echo ""
echo "Step 2: Installing pre-ssh hook..."

HOOK_SOURCE="$PROJECT_ROOT/hooks/pre-ssh.sh"
HOOK_DEST="$HOME/.config/aishellguard/hooks/pre-ssh.sh"

mkdir -p "$(dirname "$HOOK_DEST")"

if [[ -e "$HOOK_DEST" ]]; then
    echo -e "${YELLOW}⚠${NC} Existing hook found, backing up..."
    mv "$HOOK_DEST" "$HOOK_DEST.backup.$(date +%Y%m%d-%H%M%S)"
fi

ln -sf "$HOOK_SOURCE" "$HOOK_DEST"
chmod +x "$HOOK_SOURCE"
echo -e "${GREEN}✓${NC} Hook installed: $HOOK_DEST"

# Create state file directory
echo ""
echo "Step 3: Setting up state file..."

STATE_DIR="$HOME/.config/aishellguard"
STATE_FILE="$STATE_DIR/hosts.json"

mkdir -p "$STATE_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
    # Copy example state file
    cp "$PROJECT_ROOT/schemas/example-state.json" "$STATE_FILE"
    echo -e "${GREEN}✓${NC} State file created: $STATE_FILE"
else
    echo -e "${YELLOW}⚠${NC} State file already exists: $STATE_FILE"
fi

# Create log directory
mkdir -p "$HOME/.config/aishellguard/logs"

# Install app
echo ""
echo "Step 4: Installing application..."

APP_DEST="$HOME/Applications/$APP_NAME.app"

# swift build makes a bare executable, so wrap it in an app bundle.
# Bundle.module looks for the resource bundle at the .app's root.
BIN_DIR="$PROJECT_ROOT/.build/release"
APP_SOURCE="$BIN_DIR/$APP_NAME.app"
rm -rf "$APP_SOURCE"
mkdir -p "$APP_SOURCE/Contents/MacOS"
cp "$BIN_DIR/$APP_NAME" "$APP_SOURCE/Contents/MacOS/$APP_NAME"
cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_SOURCE/"
cp "$PROJECT_ROOT/Info.plist" "$APP_SOURCE/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "$APP_NAME" "$APP_SOURCE/Contents/Info.plist"

if [[ -n "$APP_SOURCE" ]]; then
    mkdir -p "$HOME/Applications"

    if [[ -d "$APP_DEST" ]]; then
        echo -e "${YELLOW}⚠${NC} Removing existing app..."
        rm -rf "$APP_DEST"
    fi

    cp -R "$APP_SOURCE" "$APP_DEST"
    echo -e "${GREEN}✓${NC} App installed: $APP_DEST"
else
    echo "Skipping app installation"
fi

# Add to login items (optional)
echo ""
read -p "Add AIShell Guard to Login Items (start at boot)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_DEST\", hidden:false}"
    echo -e "${GREEN}✓${NC} Added to Login Items"
fi

# Start the app
echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Start AIShell Guard: open ~/Applications/AIShellGuard.app"
echo "  2. Look for the network icon in menu bar"
echo "  3. Configure host authorizations"
echo ""
echo "To test the hook:"
echo "  ./scripts/test-hook.sh"
echo ""
echo "State file location:"
echo "  $STATE_FILE"
echo ""
echo "Hook log:"
echo "  ~/.config/aishellguard/hook.log"
echo ""
