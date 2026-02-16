# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Laws

**LAW #7: Never Use Ancient Bash**
- ALWAYS use `#!/usr/bin/env bash`, NEVER `#!/bin/bash`
- `/bin/bash` on macOS is v3.2.57 from 2007 (frozen due to GPL)
- `#!/usr/bin/env bash` resolves to modern Homebrew bash (v5.3+)

**LAW #8: Never Work on Main**
- NEVER commit directly to main/master branches
- Always create feature/fix branches: `git checkout -b feat/name`
- PRs merge to main, never direct commits

**Stack Preferences**
- **bun** for package management (NOT npm/yarn)
- **uv** for Python (NOT pip)

## Build Commands

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Run a single test
swift test --filter StateManagerTests/testAddHost

# Run debug build
./.build/debug/AIShellGuard

# Run release build
./.build/release/AIShellGuard
```

## Testing the Hook

The pre-ssh hook is bash and requires `jq`:

```bash
# Test against a specific host (uses real state file)
./hooks/pre-ssh.sh ssh rico@10.71.1.8

# Manual state file validation
jq . ~/.config/aishellguard/hosts.json

# Watch hook logs
tail -f ~/.config/aishellguard/hook.log
```

## Architecture Overview

AIShell Guard is a **macOS menu bar application** that controls which SSH connections AI coding assistants can make. It works by intercepting SSH commands via a hook script that checks authorization state before allowing connections.

### Core Flow

```
SSH Command → CC hook (verify-ssh-target.ts) → HTTP API → allow/block
                          ↓
                  Menu Bar App (SwiftUI)
                          ↓
                  StateManager → hosts.json (with optional HMAC signing)
```

### Local API

The app runs a local HTTP API on `127.0.0.1:27182` (loopback only, configurable via UserDefaults `apiPort`).

**Never read/write ssh-permissions.json or hosts.json directly. All SSH state goes through the app API.**

**Endpoint:** `GET /check?host=<ip_or_hostname>&user=<user>`

Response (known host):
```json
{"state":"allowed","hostname":"proxmox02","ip":"10.71.1.8","user":"rico","note":"..."}
```

Response (unknown host):
```json
{"state":"unknown"}
```

**Testing the API:**
```bash
# App must be running
curl http://127.0.0.1:27182/check?host=10.71.1.5&user=root
curl http://127.0.0.1:27182/check?host=10.99.99.99&user=root  # unknown
```

### Key Components

**API Server (`APIServer.swift`)**
- Local HTTP server using Network.framework (`NWListener`)
- Binds to `127.0.0.1` only (loopback, no external access)
- Endpoint: `GET /check?host=<ip>&user=<user>`
- Queries StateManager for host authorization state

**State Management (`StateManager.swift`)**
- Single source of truth for host authorization state
- Reads/writes JSON state file with atomic writes
- Optional HMAC-SHA256 signature verification via `HMACSigner.swift`
- `@MainActor` for thread safety with SwiftUI

**Menu Bar (`MenuBarManager.swift`)**
- Uses `NSStatusItem` for menu bar presence (AppKit)
- SwiftUI popover via `NSPopover` containing `MenuBarPopoverView`
- Runs as `.accessory` activation policy (no dock icon by default)

**CC Hook (`~/.config/pai/hooks/verify-ssh-target.ts`)**
- Bun/TypeScript PreToolUse hook for Claude Code sessions
- Queries running AIShell Guard app via HTTP API (port 27182)
- Blocks SSH if app is not running, host is blocked, or host is unknown
- Returns exit 0 (allow) or exit 2 (block)

**Legacy Hook Script (`hooks/pre-ssh.sh`)**
- Bash script for non-CC SSH interception
- Reads JSON state file directly with `jq`
- Unknown hosts added to pending queue, blocked until authorized
- Returns exit 0 (allow) or 1 (block)

**Data Models (`Models/`)**
- `Host`: Authorized host with state (allowed/ask/blocked), IP, user, tags
- `PendingHost`: Unknown host detected by hook, awaiting user decision
- `SSHPermissionsState`: Root structure containing hosts, pending queue, group order
- `SSHState`: Enum for authorization states with cycling logic

### State File Locations

The hook checks in priority order:
1. `$AISHELLGUARD_STATE_FILE` environment variable
2. macOS UserDefaults (`com.aishellguard.app` → `stateFilePath`)
3. PAI infrastructure path: `~/.config/pai/infrastructure/ssh-permissions.json`
4. Default: `~/.config/aishellguard/hosts.json`

### Window Management

The app temporarily switches activation policy when opening windows (`.accessory` → `.regular` → `.accessory`) to enable proper keyboard focus in a menu bar app. See `WindowActivation` enum in `SSHGuardApp.swift`.

### Testing

Tests use `@MainActor` and create isolated temp directories for state files. StateManager can be initialized with a custom `stateFilePath` for testing.

## Swift/SwiftUI Patterns

- All UI is SwiftUI, menu bar integration uses AppKit (`NSStatusItem`, `NSPopover`)
- `@StateObject` for owned state, `@ObservedObject` for passed state
- Async/await for file I/O operations
- `Bundle.module` for accessing PNG resources in SPM
