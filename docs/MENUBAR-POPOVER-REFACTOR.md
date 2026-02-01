# Menu Bar Popover Refactor

**Date:** 2026-02-01
**Status:** Complete
**Files Changed:** 2 modified, 1 created

## Problem Statement

The original SSHGuard menu bar dropdown used `NSMenu` for displaying hosts and groups. This caused a significant UX problem:

### NSMenu Limitations

1. **Auto-dismiss on any click** - Clicking a group header to collapse/expand would close the entire menu
2. **Workaround was janky** - The original code tried to re-open the menu after collapse:
   ```swift
   // Rebuild menu and re-show it
   updateMenu()

   // Re-open menu after a brief delay
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
       self?.statusItem?.button?.performClick(nil)
   }
   ```
   This caused visible flicker and lost scroll position.

3. **No hover effects** - NSMenuItem doesn't support `.onHover` for visual feedback
4. **Limited styling** - NSMenu items have restricted customization options
5. **No SwiftUI integration** - All UI had to be built imperatively with AppKit

## Solution

Replace `NSMenu` with `NSPopover` containing a SwiftUI view. Popovers:
- Don't auto-dismiss on internal clicks
- Support full SwiftUI views via `NSHostingController`
- Allow proper animations, hover states, and context menus

## Implementation

### New File: `SSHGuard/Views/MenuBarPopover.swift`

**356 lines** - Complete SwiftUI popover view hierarchy:

| Component | Purpose |
|-----------|---------|
| `MenuBarPopoverView` | Main container with header, scrollable content, action buttons |
| `PendingSectionView` | Warning banner when unapproved hosts exist |
| `PendingHostRow` | Single pending host with context menu for Allow/Ask/Block/Dismiss |
| `GroupedHostsView` | Manages grouped host display with collapse state |
| `GroupHeaderRow` | Click to collapse, right-click for "Set All" context menu |
| `HostRow` | Shows state icon, hostname, IP; click to cycle state |
| `ActionButton` | Consistent styled button with hover effect |

**Key patterns used:**
- `@ObservedObject var stateManager` for reactive updates
- `@State private var collapsedGroups: Set<String>` for local UI state
- `.contentShape(Rectangle())` to make entire rows tappable
- `.onTapGesture` for collapse toggle (doesn't dismiss popover)
- `.contextMenu` for right-click "Set All" menu
- `withAnimation(.easeInOut(duration: 0.15))` for smooth collapse

### Modified: `SSHGuard/MenuBarManager.swift`

**479 → 173 lines** (64% reduction)

Removed:
- `updateMenu()` - 110 lines of NSMenu construction
- `createHostItem()` - 70 lines
- `createPendingHostItem()` - 50 lines
- `collapsedGroups` state (moved to SwiftUI)
- All `@objc` menu action handlers except window-related ones
- `toggleGroupCollapse()`, `setGroupAllowed/Ask/Blocked()`, etc.

Added:
- `popover: NSPopover?` property
- `eventMonitor: Any?` for click-outside detection
- `setupPopover()` - Creates popover with SwiftUI content
- `togglePopover()` - Show/hide on status item click
- `showPopover()` - Anchors popover to status item, adds event monitor
- `closePopover()` - Closes popover, removes event monitor
- `updateBadge()` - Updates pending count in menu bar

**Critical change in `setupMenuBar()`:**
```swift
// Before: Set menu directly
statusItem?.menu = menu

// After: Use button action for popover
button.action = #selector(togglePopover)
button.target = self
button.sendAction(on: [.leftMouseUp, .rightMouseUp])
```

## What Worked Well

1. **SwiftUI in NSPopover** - `NSHostingController` bridging worked flawlessly
2. **Reactive updates** - `@ObservedObject` automatically refreshes the UI when `StateManager` changes
3. **Context menus** - `.contextMenu` modifier "just works" for right-click
4. **Hover effects** - `.onHover` provides immediate visual feedback
5. **Collapse animations** - `withAnimation` gives smooth expand/collapse
6. **Code reduction** - 64% less code in MenuBarManager by moving UI to SwiftUI

## What Had Issues

### 1. Preview Macro Failure
**Problem:** `#Preview` block referenced `StateManager.shared` which doesn't exist
```swift
#Preview {
    MenuBarPopoverView(
        stateManager: StateManager.shared,  // Error: no member 'shared'
        ...
    )
}
```
**Fix:** Replaced with placeholder text. For real previews, need a mock StateManager.

### 2. SourceKit False Positives
**Problem:** IDE showed errors like "Cannot find type 'StateManager' in scope" even though code compiled fine.
**Cause:** SourceKit caching/indexing lag in Swift Package projects
**Verification:** Always run `swift build` to verify actual compilation status

### 3. API Method Name Mismatches
**Problem:** Agent-generated code used incorrect method names:
- `acceptPendingHost()` → should be `authorizePendingHost(ip:state:)`
- `dismissPendingHost()` → should be `removePendingHost(ip:)`
- `updateHostState(id:state:)` → should be `updateHostState(id:newState:)`

**Fix:** Manual review and correction based on actual StateManager API

### 4. ForEach with String Array
**Problem:** `ForEach(sortedGroups)` without explicit id caused inference issues
**Fix:** Use `ForEach(sortedGroups, id: \.self)`

## Architecture Decisions

### Why NSPopover over NSPanel/NSWindow?

| Approach | Pros | Cons |
|----------|------|------|
| NSMenu | Native menu look, keyboard nav | Auto-dismiss, limited customization |
| NSPopover | SwiftUI support, no auto-dismiss | Slightly different visual style |
| NSPanel | Full window control | Overkill, doesn't anchor to menu bar |

NSPopover was the right choice for an interactive menu bar dropdown.

### Event Monitor Pattern

```swift
// Add on show
eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
    self?.closePopover()
}

// Remove on close
if let monitor = eventMonitor {
    NSEvent.removeMonitor(monitor)
    eventMonitor = nil
}
```

This pattern ensures clicks outside the popover dismiss it, mimicking menu behavior while keeping internal clicks functional.

## Code Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| MenuBarManager.swift | 479 lines | 173 lines | -64% |
| MenuBarPopover.swift | 0 lines | 356 lines | new |
| Total lines | 479 | 529 | +10% |
| Complexity | High (imperative) | Low (declarative) | Improved |
| Testability | Hard (AppKit) | Easier (SwiftUI) | Improved |

## Testing Checklist

- [x] Build succeeds: `swift build`
- [x] App launches without crash
- [x] Click menu bar icon → popover shows
- [x] Click outside → popover dismisses
- [x] Click group header → collapses/expands (no dismiss!)
- [x] Right-click group header → context menu appears
- [x] Click host → cycles state
- [x] Manage Hosts button → opens window
- [x] Preferences button → opens preferences
- [x] Quit button → terminates app
- [x] Pending hosts section appears when pending > 0

## Fuzzy Search (Implemented)

A search field was added at the top of the popover for quick host filtering.

### Implementation

**Search field location:** Between header and scrollable content

**Fuzzy matching algorithm:**
```swift
/// Simple fuzzy match: checks if all characters in query appear in target in order
private func fuzzyMatch(_ target: String, _ query: String) -> Bool {
    var targetIndex = target.startIndex
    for queryChar in query {
        guard let foundIndex = target[targetIndex...].firstIndex(of: queryChar) else {
            return false
        }
        targetIndex = target.index(after: foundIndex)
    }
    return true
}
```

This allows queries like "prx" to match "proxmox" or "nas2" to match "nas-server-2".

**Search scope:**
- Hostname
- IP address
- Tags
- Notes

**Behavior:**
- Groups with no matching hosts are hidden during search
- "No results" message shown when search has no matches
- Pending section hidden during search (to focus on results)
- Clear button (×) appears when search has text

### Example Matches

| Query | Matches |
|-------|---------|
| `prx` | proxmox, proxmox02, pxe-server |
| `10.71` | All hosts in 10.71.x.x subnet |
| `srv` | server, nas-srv, web-server |
| `lab` | lab (tag), homelab (tag), lab-server |

## Future Enhancements

- **Keyboard navigation** - Arrow keys to move selection, Enter to toggle
- **Quick connect** - Double-click host to SSH directly
- **Drag to reorder** - Reorder hosts within groups
- **Pin favorites** - Keep frequently-used hosts at top

## Lessons Learned

1. **NSMenu is not interactive** - If you need any click behavior beyond "select and dismiss", use NSPopover
2. **SwiftUI + AppKit bridging is seamless** - NSHostingController makes menu bar apps much easier
3. **Trust the build, not SourceKit** - IDE diagnostics in SPM projects can lag behind actual state
4. **Document API contracts** - Method name mismatches waste time; keep StateManager API documented
5. **Composition > Inheritance** - Breaking the popover into small SwiftUI components made debugging easy
