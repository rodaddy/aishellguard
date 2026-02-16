## CHECKPOINT -- 2026-02-16

**Branch:** `wip`
**Last commit:** `9682b27` session: wrap 2026-02-16

### What's done
- Local HTTP API server (`APIServer.swift`) on 127.0.0.1:27182
- CC hook (`verify-ssh-target.ts`) queries API instead of reading files
- App built, installed to ~/Applications, API verified working
- Session files committed

### What's pending (uncommitted)
- `SSHGuard/APIServer.swift` (new)
- `SSHGuard/SSHGuardApp.swift` (modified)
- `SSHGuard/Settings.swift` (modified)
- `CLAUDE.md` (modified)
- `scripts/install.sh` (modified)

### Next
- PR the API server code to main
- Test hook end-to-end with real CC SSH attempt
- Consider /status health check endpoint

### Files for context
- `.reports/session.md` -- full session summary
- `.reports/briefing.md` -- compact briefing
