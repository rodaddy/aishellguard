# Session Summary

**Date:** 2026-02-16
**Project:** AIShell Guard (ssh-guard)

## What Got Done
- Implemented local HTTP API server (`APIServer.swift`) using Network.framework `NWListener`
- Server binds to `127.0.0.1:27182` (loopback only), single endpoint: `GET /check?host=&user=`
- Added `apiPort` setting to `AppSettings` (UserDefaults, default 27182)
- Wired `APIServer` into `SSHGuardApp` as `@StateObject` alongside `MenuBarManager`
- Rewrote `~/.config/pai/hooks/verify-ssh-target.ts` to query API instead of reading state files directly
- Updated `CLAUDE.md` with API docs, endpoint reference, and "never read files directly" rule
- Updated `scripts/install.sh` with API port info in post-install output
- Built release bundle and installed to `~/Applications/AIShell Guard.app`
- Verified API responds correctly for known hosts (`allowed`) and unknown hosts (`unknown`)

## Key Decisions
- Used Network.framework (`NWListener`) for zero-dependency HTTP server -- no external libs
- `@MainActor` on `APIServer`, NWListener callbacks dispatched back via `Task { @MainActor in }`
- Hook fails closed (exit 2) when app is not running -- CC cannot SSH without the guard
- `AISHELLGUARD_API_PORT` env var available for port override in the hook
- Reused existing `findHost(byIPOrHostname:)` on `SSHPermissionsState` for lookups

## Files Changed
- `SSHGuard/APIServer.swift` - **Created** - HTTP API server (~115 lines)
- `SSHGuard/SSHGuardApp.swift` - Added `APIServer` as `@StateObject`
- `SSHGuard/Settings.swift` - Added `apiPort` key and computed property
- `~/.config/pai/hooks/verify-ssh-target.ts` - Rewritten to use HTTP API
- `CLAUDE.md` - Added API server docs, endpoint reference, rules
- `scripts/install.sh` - Added API port info to post-install output

## Blockers/Issues
- `swift test` has pre-existing linker failure (SwiftUICore client restriction) -- not caused by this work
- Pre-existing concurrency warnings in `StateManager.swift` and `MenuBarManager.swift`

## Next Session
- Test the hook end-to-end with a real CC SSH attempt
- Consider adding a `/status` endpoint for health checks
- Fix the pre-existing `swift test` linker issue if tests are needed
