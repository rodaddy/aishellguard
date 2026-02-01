# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Preferences window for HMAC signing configuration
- Host editor window for detailed host management
- Menu bar icon style customization
- Support for keyboard navigation in menu bar popover
- Host tagging system for organization (planned)
- Drag-to-reorder hosts within groups (planned)
- Pin favorites feature (planned)

### Changed
- Improved performance of group management operations

### Fixed
- Keyboard focus management in menu bar app windows

## [1.0.0] - 2026-02-01

### Added

#### Core Features
- Menu bar app for SSH host authorization management
- Three authorization states with visual indicators:
  - 🟢 **Allowed** - SSH permitted without prompts
  - ⚪ **Ask** - Requires confirmation before SSH
  - 🔴 **Blocked** - SSH explicitly denied
- Pre-SSH hook integration for Claude Code, Cursor, and Windsurf
- Unknown host detection with pending queue notifications
- Host grouping with custom drag-and-drop group reordering
- State file persistence at `~/.config/aishellguard/hosts.json`

#### Menu Bar Interface
- Expandable/collapsible host groups (click group header)
- Fuzzy search across hostnames, IPs, tags, and notes
- Context menus for batch operations:
  - Group headers: "Set All To: Allowed/Ask/Blocked"
  - Pending hosts: "Allow/Ask/Block/Dismiss"
- One-click state cycling by clicking host entry
- Pending hosts section with warning badge
- Real-time host count display in menu bar
- Smooth collapse/expand animations

#### Host Management
- Full host management window with table view
- Add new SSH hosts with hostname, IP, username, and notes
- Edit existing host details
- Remove hosts from authorization list
- Move hosts between groups
- Support for multiple tags per host
- Host information persists across application restarts

#### Preferences & Configuration
- Configurable state file path (defaults to `~/.config/pai/infrastructure/ssh-permissions.json`)
- HMAC-SHA256 signature verification toggle
- Menu bar icon style selection
- Settings persistent across sessions

#### Security
- Keychain-based HMAC signing key storage
  - Secure key generation and retrieval
  - Automatic key creation if not present
- HMAC-SHA256 signature verification for state file integrity
- Atomic file writes to prevent corruption
- Signature verification on state file load with tampering detection

#### Architecture
- SwiftUI-based menu bar popover (replacing NSMenu)
- NSPopover with click-outside detection for native popover behavior
- Reactive state management via `@ObservedObject`
- Observable `StateManager` class for centralized state
- JSON-based persistent state with atomic writes
- Flexible date formatting (with/without fractional seconds)
- Comprehensive host and pending host data models

#### Host Model
- Host structure with fields:
  - `id`: Unique identifier (UUID-based)
  - `hostname`: Optional DNS name
  - `ip`: IP address (unique)
  - `user`: SSH username (default: "rico")
  - `state`: Authorization state (allowed/ask/blocked)
  - `note`: Optional description
  - `lastUsed`: Timestamp of last access
  - `tags`: List of tags for grouping

#### Pending Host Management
- Automatic detection of unknown SSH hosts
- `PendingHost` structure with:
  - `ip`: Host IP address
  - `user`: Attempted SSH username
  - `detectedAt`: Timestamp of detection
  - `attemptedBy`: Which tool initiated SSH (e.g., "claude-code")
- Batch authorize/dismiss operations
- Prevents duplicate pending entries

#### State Management
- `SSHPermissionsState` root structure with:
  - `version`: File format version ("1.0")
  - `machine`: Machine identifier
  - `lastUpdated`: Last modification timestamp
  - `hosts`: Array of authorized hosts
  - `pending`: Array of pending/unknown hosts
  - `groupOrder`: Custom group ordering array
  - `signature`: Optional HMAC signature for integrity
- Custom JSON encoding/decoding with ISO 8601 dates
- Signature generation and verification
- Sorted groups with custom ordering (maintains groupOrder, alphabetical fallback)

#### File Operations
- Load state from disk with signature verification
- Save state with atomic writes (write-temp-rename pattern)
- Automatic directory creation if missing
- Flexible date format handling (with/without fractional seconds)
- Error handling and reporting

#### UI Components
- `MenuBarPopoverView`: Main container with header, search, content, action buttons
- `PendingSectionView`: Warning banner for pending hosts
- `PendingHostRow`: Individual pending host with context menu
- `GroupedHostsView`: Groups display with collapse functionality
- `GroupHeaderRow`: Clickable group header with batch actions
- `HostRow`: Host entry with state icon, name, IP, state cycling
- `ActionButton`: Consistent button styling with hover effects
- `ManageHostsWindow`: Full host management interface
- `HostEditorWindow`: Individual host editor
- `PreferencesWindow`: Settings interface

#### Command-Line / Hook Integration
- `pre-ssh.sh` hook for Claude Code hook integration
- Hook checks host authorization before SSH
- Returns appropriate exit codes for allowed/blocked/ask states
- Integrates with standard shell hooks directory

### Changed
- Replaced NSMenu-based menu bar with NSPopover for better UX
- Removed NSMenu auto-dismiss limitation
- Eliminated janky re-open workaround in menu bar popover
- Improved code organization: 64% reduction in MenuBarManager complexity

### Security
- HMAC-SHA256 cryptographic signatures prevent unauthorized state modifications
- Keychain integration for secure signing key storage
- Signature verification rejects tampered state files
- Atomic file writes prevent partial/corrupted state

### Technical Details

#### JSON State File Format
```json
{
  "version": "1.0",
  "machine": "mac-studio",
  "lastUpdated": "2026-02-01T12:34:56.789Z",
  "hosts": [
    {
      "id": "host-abc12345",
      "hostname": "proxmox02",
      "ip": "10.71.1.8",
      "user": "rico",
      "state": "allowed",
      "note": "Primary Proxmox host",
      "lastUsed": "2026-02-01T12:00:00.000Z",
      "tags": ["infra", "primary"]
    }
  ],
  "pending": [
    {
      "ip": "10.71.2.15",
      "user": "root",
      "detectedAt": "2026-02-01T11:00:00.000Z",
      "attemptedBy": "claude-code"
    }
  ],
  "groupOrder": ["infra", "lab", "vps"],
  "signature": "base64-encoded-hmac-sha256-signature"
}
```

#### Build & Runtime
- **Language**: Swift 5.7+
- **Minimum macOS**: 12.0
- **Xcode**: 14.0+
- **Build System**: Swift Package Manager
- **Target**: Native macOS menu bar app

#### Development Features
- Comprehensive test suite via XCTest
- State management unit tests
- Mock state file for testing
- ISO 8601 date handling tests

### Known Limitations
- HMAC signing key stored in Keychain (security note: subject to macOS login password)
- State file location hardcoded to `~/.config/aishellguard/hosts.json` (configurable via settings)
- Single-machine focus (machine ID field present for future expansion)

---

## Comparison to Similar Projects

SSHGuard differs from typical SSH config management in these ways:

1. **Per-connection decision** - Each SSH attempt is authorized at runtime, not just once at config time
2. **Visual feedback** - Menu bar indicator shows authorization status at a glance
3. **Integration-focused** - Designed specifically for AI editor pre-SSH hooks (Claude Code, Cursor, Windsurf)
4. **Zero dependencies** - Pure Swift, no external libraries or cloud sync
5. **Explicit trust model** - No implicit trust; all hosts must be explicitly authorized

---

## Future Roadmap

### Near-term (v1.1)
- Keyboard navigation (arrow keys, Enter)
- Quick connect (double-click SSH)
- Host sorting options (alphabetical, by state, by last used)

### Medium-term (v1.2+)
- Time-based temporary authorization (allow for 1 hour)
- IP address whitelisting
- SSH certificate pinning
- Host group templates
- Export/import host lists

### Long-term (v2.0)
- Multi-machine sync via PAI infrastructure
- Audit log of all SSH attempts
- Per-host command filtering
- Integration with PAI permission system
- Mobile app for approvals

---

[Unreleased]: https://github.com/rodaddy/ssh-guard/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rodaddy/ssh-guard/releases/tag/v1.0.0
