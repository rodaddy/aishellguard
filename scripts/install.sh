#!/usr/bin/env zsh
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
echo "Step 1: Building $APP_NAME.app bundle..."
cd "$PROJECT_ROOT"

"$PROJECT_ROOT/scripts/bundle.sh"
echo -e "${GREEN}✓${NC} Bundle creation complete"

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
APP_SOURCE="$PROJECT_ROOT/.build/release/$APP_NAME.app"

if [[ -d "$APP_SOURCE" ]]; then
    mkdir -p "$HOME/Applications"

    if [[ -d "$APP_DEST" ]]; then
        echo -e "${YELLOW}⚠${NC} Removing existing app..."
        rm -rf "$APP_DEST"
    fi

    cp -R "$APP_SOURCE" "$APP_DEST"
    echo -e "${GREEN}✓${NC} App installed: $APP_DEST"
else
    echo -e "${YELLOW}⚠${NC} Could not find built app at $APP_SOURCE"
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
echo "Local API (for Claude Code hooks):"
echo "  Port: 27182 (default, configurable in app settings)"
echo "  Test: curl http://127.0.0.1:27182/check?host=10.71.1.5&user=root"
echo "  NOTE: App must be running for CC SSH checks to work."
echo ""
echo "To test the hook:"
echo "  ./scripts/test-hook.sh"
echo ""
echo "State file location:"
echo "  $STATE_FILE"
echo ""
echo "Hook log:"
echo "  ~/.config/aishellguard/logs/ssh-guard-hook.log"
echo ""
