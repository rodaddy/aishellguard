**Last session:** 2026-02-16 -- Added local HTTP API server so CC queries the app instead of reading state files
**Done:**
- Created `APIServer.swift` -- NWListener on 127.0.0.1:27182, `GET /check?host=&user=`
- Rewrote `verify-ssh-target.ts` hook to use API (fails closed if app not running)
- Added `apiPort` setting, wired server into app lifecycle
- Built, installed to ~/Applications, verified API works
**Decisions:** Network.framework (no deps), fail closed when app down, reused `findHost(byIPOrHostname:)`
**Next:** Test hook with real CC SSH, consider /status endpoint, fix swift test linker issue
**Phase:** API server complete and deployed, hook updated
