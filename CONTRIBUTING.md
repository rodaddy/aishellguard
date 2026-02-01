# Contributing to SSHGuard

We appreciate your interest in contributing to SSHGuard! This document outlines the process for contributing code, reporting bugs, and improving documentation.

## Welcome

SSHGuard is a macOS menu bar app that brings explicit SSH authorization control to your workflow. Whether you're fixing bugs, adding features, or improving docs, your contributions help make SSH management safer and more transparent.

## How to Contribute

### Reporting Issues

Found a bug or have a feature idea? Please open a GitHub issue with:

- **Clear title** - What's the problem or feature request?
- **Description** - What did you try? What happened? What did you expect?
- **Environment** - macOS version, Xcode version, Swift version
- **Steps to reproduce** - Exact steps to trigger the issue
- **Screenshots** - If applicable, show menu bar state or error messages

### Submitting Pull Requests

1. **Fork and branch** - Create a feature branch from `main`
   ```bash
   git clone https://github.com/yourusername/ssh-guard.git
   cd ssh-guard
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** - Follow the code style guidelines below

3. **Test your changes** - Run tests and manual verification

4. **Commit with clear messages** - Describe what changed and why

5. **Push and open PR** - Reference any related issues

6. **Respond to review** - Address feedback from maintainers

## Development Setup

### Requirements

- **macOS 13.0+** - SSHGuard is a native macOS app
- **Swift 5.9+** - Minimum Swift version from Package.swift
- **Xcode 15+** - For building and testing
- **jq** - For testing the pre-ssh hook (install via `brew install jq`)

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/ssh-guard.git
cd ssh-guard

# Verify Swift version
swift --version
# Should output Swift 5.9+

# Build the project
swift build

# Run tests
swift test
```

## Building

### Development Build

```bash
# Build in debug mode
swift build

# Run the app
./.build/debug/SSHGuard
```

### Release Build

```bash
# Build optimized release binary
swift build -c release

# Binary location
./.build/release/SSHGuard
```

### Installing Locally

```bash
# Copy to Applications folder
cp -r ./.build/release/SSHGuard /Applications/SSHGuard.app

# Run the app
open /Applications/SSHGuard.app
```

## Testing the Hook

The pre-ssh hook is critical to SSHGuard's security model. Before submitting changes that affect hook behavior, test it thoroughly.

### Hook Test Commands

```bash
# Test allowed host (should exit 0)
./hooks/pre-ssh.sh ssh rico@10.71.1.8
# Expected output: ✅ SSH to rico@10.71.1.8 is ALLOWED

# Test unknown host (should exit 1, adds to pending)
./hooks/pre-ssh.sh ssh rico@10.71.20.99
# Expected output: ❓ Unknown host, added to pending

# Test blocked host (should exit 1)
./hooks/pre-ssh.sh ssh root@10.71.20.55
# Expected output: 🔴 SSH to root@10.71.20.55 is BLOCKED
```

### Validating the State File

```bash
# Validate JSON syntax
jq . ~/.config/pai/infrastructure/ssh-permissions.json

# Pretty-print the state file
jq '.' ~/.config/pai/infrastructure/ssh-permissions.json

# Check pending hosts
jq '.pending' ~/.config/pai/infrastructure/ssh-permissions.json

# Check host states
jq '.hosts[] | {id, state}' ~/.config/pai/infrastructure/ssh-permissions.json
```

### Hook Debugging

```bash
# Watch the hook log in real-time
tail -f ~/.config/pai/logs/ssh-guard-hook.log

# Check hook installation
ls -la ~/.config/pai-private/hooks/pre-ssh.sh

# Verify hook is executable
ls -l ./hooks/pre-ssh.sh
```

## Code Style

### Swift Standards

SSHGuard follows standard Swift conventions:

- **Naming** - Use camelCase for variables and functions, PascalCase for types
- **Indentation** - 4 spaces (standard in Swift)
- **Braces** - Opening brace on same line (K&R style)
- **Line length** - Aim for 100 characters, never exceed 120
- **Comments** - Document complex logic, but prefer clear code over comments

Example:

```swift
// Good - clear, concise, follows Swift idioms
struct HostState: Codable {
    let id: String
    let hostname: String
    let state: AuthorizationState
}

// Bad - unclear naming, excessive comments
struct HS: Codable {
    // The unique identifier for this host
    let i: String
    // The hostname or IP
    let h: String
}
```

### SwiftUI for UI Components

All UI code uses SwiftUI. Avoid AppKit where possible.

- **View structure** - Break complex views into smaller, reusable components
- **State management** - Use @State, @ObservedObject, @StateObject appropriately
- **Binding** - Pass bindings for data that changes frequently
- **Preview** - Include preview providers for design-time testing

Example:

```swift
struct HostRow: View {
    @ObservedObject var host: Host

    var body: some View {
        HStack {
            Image(systemName: host.icon)
                .foregroundColor(host.color)
            VStack(alignment: .leading) {
                Text(host.hostname)
                    .font(.headline)
                Text(host.ip)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                Button("Allow", action: { host.state = .allowed })
                Button("Ask", action: { host.state = .ask })
                Button("Block", action: { host.state = .blocked })
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

#Preview {
    HostRow(host: .preview)
}
```

### State File Format

The `ssh-permissions.json` state file uses consistent formatting:

```json
{
  "version": "1.0",
  "hosts": [
    {
      "id": "proxmox-01",
      "hostname": "proxmox01",
      "ip": "10.71.1.8",
      "user": "rico",
      "state": "allowed",
      "note": "Primary Proxmox host",
      "lastUsed": "2026-01-31T23:45:00Z",
      "tags": ["production", "infrastructure"]
    }
  ],
  "pending": []
}
```

**JSON rules:**
- Pretty-print with 2-space indentation
- Always include version field
- Maintain alphabetical order of host properties
- Use ISO 8601 timestamps (UTC with Z suffix)

### Error Handling

- Use Swift's Result type for operations that can fail
- Provide meaningful error messages that users can act on
- Log errors with context for debugging

```swift
enum SSHGuardError: LocalizedError {
    case stateFileNotFound
    case invalidJSON(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .stateFileNotFound:
            return "SSH permissions file not found"
        case .invalidJSON(let details):
            return "Invalid permissions file: \(details)"
        case .permissionDenied:
            return "Cannot write to permissions file"
        }
    }
}
```

## Pull Request Process

1. **Update tests** - If adding features, include tests
2. **Test the hook** - Run hook tests if modifying hook behavior
3. **Check linting** - Use `swiftformat` or `swiftlint` if available
4. **Update documentation** - Keep README and hook docs in sync
5. **Add to CHANGELOG** - Document your changes
6. **Request review** - Tag maintainers for feedback

### PR Checklist

- [ ] Tests added/updated for new functionality
- [ ] Hook tested (if applicable)
- [ ] Code follows Swift style guidelines
- [ ] Documentation updated
- [ ] No unnecessary dependencies added
- [ ] Commits are atomic and well-described

## Code of Conduct

We follow a simple code of conduct:

- **Be respectful** - Treat all contributors with respect
- **Be constructive** - Provide helpful feedback, not criticism
- **Be inclusive** - Welcome people of all backgrounds and experience levels
- **Be safe** - SSHGuard controls security-critical operations; safety matters

## Project Structure

```
ssh-guard/
├── SSHGuard/                    # Main app target
│   ├── Models/                  # Data types (Host, AuthorizationState)
│   ├── Views/                   # SwiftUI components
│   ├── MenuBarManager.swift      # Menu bar integration
│   ├── StateManager.swift        # State file I/O
│   ├── SSHGuardApp.swift         # App entry point
│   └── Resources/                # Icons, assets
├── SSHGuardTests/               # Unit tests
├── hooks/                        # CLI hooks (pre-ssh.sh)
├── docs/                         # Architecture documentation
├── Package.swift                 # SPM manifest
└── README.md                     # User documentation
```

## Questions or Need Help?

- **Documentation** - See `/docs` directory for architecture details
- **Hook details** - See `hooks/README.md`
- **State file design** - See `docs/STATE-FILE-DESIGN.md`
- **Issues** - Search existing issues or open a new one

## License

SSHGuard is provided as-is for private development. License terms will be determined when/if the project is made public.

---

Thank you for contributing to SSHGuard! Your help makes SSH management safer and more transparent.
