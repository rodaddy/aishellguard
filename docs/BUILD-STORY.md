# How AIShell Guard was built

This is the build history of AIShell Guard, taken from its git log (16
commits, 2026-02-01 to 2026-03-13), `CHANGELOG.md`, the two design notes in
`docs/`, the hook test script and the unit tests. This public repository is
a one-commit snapshot of that history.

## The problem

AI coding assistants can run `ssh` like any other shell command. The author
was letting agents work against a home lab and wanted a person to decide,
per host, whether an agent may connect: always, never, or ask first. The
decision had to be fast to change from the menu bar and readable by a plain
shell hook, so it works with any assistant that supports a pre-command hook.

## Timeline

The working app was built in one day, 2026-02-01, in this order:

1. Project layout and a JSON Schema for the state file
   (`schemas/`, `docs/STATE-FILE-DESIGN.md`).
2. The `pre-ssh.sh` hook: parses the SSH target, looks the host up with
   `jq`, allows, blocks or asks, queues unknown hosts as pending, logs every
   attempt. Shipped with a test script (7 of 7 cases passing at the time).
3. The Swift menu bar app: data models, a `StateManager` with atomic JSON
   writes, a status item menu, 9 unit tests for create, update, delete,
   state cycling and persistence.
4. A date-parsing fix so the app never overwrites the state file when it
   cannot parse it, then IP display and grouping by tag.
5. A configurable state file path (environment variable, then app
   preference, then default) so the hook and app always agree.
6. Host management: add and edit dialogs, a full management window with
   search, groups, drag and drop, and persisted group order.
7. A keyboard focus fix for windows opened from a menu bar app.
8. Rename from SSHGuard to AIShell Guard for public release: personal
   values replaced with `NSUserName()` and RFC 5737 documentation addresses,
   MIT licence, contributor docs, build and release workflows, optional HMAC
   signing of the state file with the key in Keychain, and a popover UI.
9. A Swift concurrency fix in a NotificationCenter observer, merged as the
   first pull request.

A funding badge was added on 2026-03-13. The source issue tracker shows only
housekeeping since: setup-gap checks in October 2026 and the removal of an
unused runtime dependency on 2026-10-27.

## Key design decisions

- **One JSON file is the contract.** The app and the hook share
  `~/.config/aishellguard/hosts.json`. A stable `id` is separate from
  hostname and IP because both can change. Writes are atomic so the hook
  never reads a half-written file.
- **Hook in shell, UI in Swift.** The hook only needs `jq`, so any assistant
  that can run a pre-command script can use it. The app is a native menu bar
  item so changing a host's state takes one click.
- **Unknown means pending, not allowed.** A host the file does not know is
  refused and queued, and the app surfaces it for a decision.
- **Popover instead of a menu.** `docs/MENUBAR-POPOVER-REFACTOR.md` records
  why: `NSMenu` closes on every click, so collapsing a group closed the menu
  and the re-open workaround flickered. A SwiftUI view in an `NSPopover`
  fixed that and allowed hover states and context menus.

## How AI was used

The app was written with Claude Opus as a pair programmer; the history
carries co-author trailers on the release commits. The design notes in
`docs/` were written alongside the code to record decisions as they were
made.

## Testing

- `SSHGuardTests/StateManagerTests.swift`: 9 unit tests (`swift test`).
- `scripts/test-hook.sh`: builds a temporary state file with allowed, ask
  and blocked hosts and checks the hook's exit codes for each.
- `.github/workflows/build.yml` builds the app on push.

## What did not work

- Date parsing that only accepted one ISO 8601 form made the app treat a
  valid file as unreadable and overwrite it. Fixed on day one by accepting
  both forms and refusing to write after a failed parse.
- Text fields in the app's windows could not take keyboard input, because a
  menu bar (accessory) app does not activate like a normal app. Fixed by
  switching the activation policy while a window is open.
- The `NSMenu` dropdown, replaced by a popover as described above.

## Current state

Version 1.0.0 (2026-02-01) with unreleased popover and preferences work in
the changelog. Small, stable and feature-complete for its purpose; not under
active development.
