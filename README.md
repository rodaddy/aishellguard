# SSHGuard

**macOS menu bar app for managing SSH authorization with Claude Code integration**

## Overview

SSHGuard provides visual, explicit authorization for SSH connections used by Claude Code (or manual SSH). Instead of implicit trust or constant confirmation prompts, you get a menu bar interface showing:

- 🟢 **Allowed** - SSH permitted without prompts
- ⚪ **Ask** - Requires confirmation before SSH
- 🔴 **Blocked** - SSH explicitly denied

## Features

- **Menu bar control** - One-click authorization state changes
- **Unknown host detection** - Automatic notifications for new SSH attempts
- **Hook integration** - Blocks SSH until authorized via pre-ssh hook
- **State persistence** - Survives reboots, app crashes
- **Zero dependencies** - Reads local JSON file, no cloud sync required

## Architecture

```
┌─────────────────────────┐
│   SSHGuard Menu Bar     │
│  ┌──────────────────┐   │
│  │ 🟢 proxmox02     │   │
│  │ 🟢 n8n (LXC 202) │   │
│  │ ⚪ postgres      │   │
│  └──────────────────┘   │
└─────────────────────────┘
         ↓
  ssh-permissions.json
         ↓
    pre-ssh.sh hook
         ↓
   ✅/❌ SSH decision
```

## Installation

```bash
# Clone repository
git clone [repo-url] ssh-guard
cd ssh-guard

# Build (requires Xcode)
xcodebuild -scheme SSHGuard -configuration Release

# Install
./scripts/install.sh
```

## State File

Located at: `~/.config/pai/infrastructure/ssh-permissions.json`

```json
{
  "version": "1.0",
  "hosts": [
    {
      "id": "proxmox02",
      "hostname": "proxmox02",
      "ip": "10.71.1.8",
      "user": "rico",
      "state": "allowed",
      "note": "Primary Proxmox host"
    }
  ]
}
```

## Hook Integration

The pre-ssh hook (`hooks/pre-ssh.sh`) checks authorization before SSH:

```bash
# Symlink to Claude Code hooks directory
ln -s ~/Development/ssh-guard/hooks/pre-ssh.sh \
      ~/.config/pai-private/hooks/pre-ssh.sh
```

## Development

**Requirements:**
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

**Build:**
```bash
xcodebuild -scheme SSHGuard
```

**Test:**
```bash
xcodebuild test -scheme SSHGuard
```

## License

(TBD - likely MIT when/if made public)

## Status

🚧 **Private development** - Iterating on UX before potential open source release
