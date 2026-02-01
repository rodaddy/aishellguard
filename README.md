# AIShell Guard

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13+-brightgreen.svg)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

**Menu bar app for controlling AI CLI tool SSH access**

## What is AIShell Guard?

AIShell Guard gives you visual, explicit control over which SSH connections your AI coding assistants can make. Instead of blindly trusting AI tools with SSH access or dealing with constant confirmation prompts, you get a simple menu bar interface to manage host authorization.

## Why?

AI coding assistants like Claude Code, Cursor, and Windsurf can execute SSH commands to deploy code, manage servers, and access remote resources. This is powerful but risky:

- **The Problem**: AI tools may attempt SSH connections you didn't intend
- **Current Solutions**: Either trust everything (dangerous) or confirm every command (annoying)
- **AIShell Guard**: Pre-authorize specific hosts with clear visual states

## Features

- **Menu Bar Control** - One-click authorization state changes
- **Three States** - Allowed (green), Ask (gray), Blocked (red)
- **Unknown Host Detection** - Automatic notification for new SSH attempts
- **Hook Integration** - Blocks SSH until authorized via pre-ssh hook
- **Host Groups** - Organize hosts with drag-and-drop reordering
- **State Persistence** - Survives reboots, app restarts
- **HMAC Verification** - Optional cryptographic integrity for state file
- **Zero Dependencies** - Local JSON file, no cloud sync required

## Screenshots

<!-- TODO: Add screenshots
![Menu Bar](docs/screenshots/menubar.png)
![Popover](docs/screenshots/popover.png)
![Manage Hosts](docs/screenshots/manage-hosts.png)
-->

## Installation

### Prerequisites

- macOS 13.0 or later
- [jq](https://stedolan.github.io/jq/) for hook script: `brew install jq`

### From Source

```bash
# Clone repository
git clone https://github.com/aishellguard/aishellguard.git
cd aishellguard

# Build
swift build -c release

# Run install script
./scripts/install.sh
```

### From Releases

Download the latest `.zip` from [Releases](https://github.com/aishellguard/aishellguard/releases), extract, and move `AIShellGuard.app` to `/Applications`.

## Quick Start

1. **Launch AIShellGuard** - Look for the lock icon in your menu bar
2. **Add your first host** - Click the menu bar icon → "Add Host"
3. **Set authorization** - Green (allowed), Gray (ask), Red (blocked)
4. **Install the hook** - See [Hook Integration](#hook-integration) below
5. **Test it** - Try SSH in your AI tool - authorized hosts work, others are blocked

## How It Works

```
┌─────────────────────────────┐
│  AIShell Guard Menu Bar     │
│  ┌───────────────────────┐  │
│  │ 🟢 server-01          │  │
│  │ 🟢 automation-01      │  │
│  │ ⚪ database-01        │  │
│  │ 🔴 proxy-01           │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
              ↓
    ~/.config/aishellguard/hosts.json
              ↓
         pre-ssh.sh hook
              ↓
        ✅ Allow / ❌ Block
```

1. **State File** stores host configurations in JSON
2. **Pre-SSH Hook** checks authorization before every SSH command
3. **Menu Bar App** provides visual control and notifications
4. **Unknown hosts** are blocked and added to pending queue for review

## Configuration

### State File

Located at: `~/.config/aishellguard/hosts.json`

```json
{
  "version": "1.0",
  "machine": "my-mac",
  "hosts": [
    {
      "id": "server-01",
      "hostname": "server-01",
      "ip": "192.0.2.10",
      "user": "admin",
      "state": "allowed",
      "note": "Primary server",
      "tags": ["production"]
    }
  ],
  "pending": []
}
```

### Host States

| State | Icon | Behavior |
|-------|------|----------|
| `allowed` | 🟢 | SSH proceeds without prompts |
| `ask` | ⚪ | SSH blocked, requires manual confirmation |
| `blocked` | 🔴 | SSH explicitly denied |

### Preferences

- **State File Location** - Customizable path
- **Menu Bar Icon** - Multiple styles available
- **HMAC Signing** - Optional state file integrity verification

## Hook Integration

AIShell Guard works by intercepting SSH commands before they execute.

### For Claude Code

Add to your Claude Code hooks configuration:

```bash
# Create hooks directory
mkdir -p ~/.config/aishellguard/hooks

# Copy hook script
cp /path/to/aishellguard/hooks/pre-ssh.sh ~/.config/aishellguard/hooks/

# Make executable
chmod +x ~/.config/aishellguard/hooks/pre-ssh.sh
```

Then configure Claude Code to use the hook for SSH commands.

### For Cursor / Windsurf

Similar hook integration - configure your tool to run `pre-ssh.sh` before SSH commands.

### Testing the Hook

```bash
# Test allowed host
./hooks/pre-ssh.sh ssh admin@192.0.2.10
# Expected: ✅ SSH allowed (exit 0)

# Test unknown host
./hooks/pre-ssh.sh ssh admin@192.0.2.99
# Expected: ❓ Unknown host, added to pending (exit 1)

# Test blocked host
./hooks/pre-ssh.sh ssh root@192.0.2.55
# Expected: 🔴 SSH blocked (exit 1)
```

### Hook Logs

Check `~/.config/aishellguard/logs/aishellguard-hook.log` for connection attempts.

## Troubleshooting

### Hook Not Running

```bash
# Check hook is executable
ls -la ~/.config/aishellguard/hooks/pre-ssh.sh

# Check jq is installed
which jq || brew install jq
```

### All SSH Blocked

```bash
# Verify state file exists and is valid JSON
cat ~/.config/aishellguard/hosts.json | jq .

# Check app is running
pgrep -l AIShellGuard
```

### State File Errors

```bash
# Reset to empty state
echo '{"version":"1.0","machine":"mac","hosts":[],"pending":[]}' > ~/.config/aishellguard/hosts.json
```

### Emergency Bypass

If the hook is broken and you need SSH immediately:

```bash
# Temporarily remove hook
mv ~/.config/aishellguard/hooks/pre-ssh.sh ~/.config/aishellguard/hooks/pre-ssh.sh.disabled

# After emergency, restore
mv ~/.config/aishellguard/hooks/pre-ssh.sh.disabled ~/.config/aishellguard/hooks/pre-ssh.sh
```

## Development

### Requirements

- macOS 13.0+
- Xcode 15.0+ or Swift 5.9+
- jq (for hook testing)

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test
```

### Project Structure

```
aishellguard/
├── Package.swift           # Swift package manifest
├── SSHGuard/              # Main app source (will rename to AIShellGuard)
│   ├── SSHGuardApp.swift  # App entry point
│   ├── StateManager.swift # State file management
│   ├── MenuBarManager.swift
│   ├── Models/
│   └── Views/
├── hooks/
│   └── pre-ssh.sh         # Claude Code hook
├── schemas/
│   └── ssh-permissions.schema.json
└── scripts/
    └── install.sh
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) - see LICENSE file for details.

## Acknowledgments

- Built for the AI coding assistant ecosystem
- Inspired by the need for explicit SSH authorization in automated workflows
