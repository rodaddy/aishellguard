import AppKit
import SwiftUI

/// Manages the menu bar status item and menu
@MainActor
class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private let stateManager: StateManager

    init(stateManager: StateManager) {
        self.stateManager = stateManager
        setupMenuBar()
    }

    /// Create and configure the menu bar item
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "SSHGuard")
            button.imagePosition = .imageLeading
        }

        updateMenu()
    }

    /// Update menu contents (call when state changes)
    func updateMenu() {
        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(title: "SSHGuard", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Pending hosts section (if any)
        if stateManager.pendingCount > 0 {
            let pendingTitle = NSMenuItem(title: "⚠️ Pending Hosts (\(stateManager.pendingCount))", action: nil, keyEquivalent: "")
            pendingTitle.isEnabled = false
            menu.addItem(pendingTitle)

            for pending in stateManager.state.pending {
                menu.addItem(createPendingHostItem(pending))
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Known hosts section - grouped by first tag
        let sortedHosts = stateManager.sortedHosts
        if sortedHosts.isEmpty {
            let hostsTitle = NSMenuItem(title: "Known Hosts", action: nil, keyEquivalent: "")
            hostsTitle.isEnabled = false
            menu.addItem(hostsTitle)

            let emptyItem = NSMenuItem(title: "  No hosts configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            // Group hosts by first tag
            let grouped = Dictionary(grouping: sortedHosts) { host -> String in
                host.tags.first ?? "ungrouped"
            }

            // Sort group names, but put "ungrouped" last
            let sortedGroups = grouped.keys.sorted { lhs, rhs in
                if lhs == "ungrouped" { return false }
                if rhs == "ungrouped" { return true }
                return lhs < rhs
            }

            for group in sortedGroups {
                guard let hosts = grouped[group] else { continue }

                // Group header
                let groupTitle = NSMenuItem(title: group.uppercased(), action: nil, keyEquivalent: "")
                groupTitle.isEnabled = false
                menu.addItem(groupTitle)

                // Hosts in this group
                for host in hosts {
                    menu.addItem(createHostItem(host))
                }

                menu.addItem(NSMenuItem.separator())
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Management
        let addHostItem = NSMenuItem(title: "Add Host...", action: #selector(handleAddHost), keyEquivalent: "n")
        addHostItem.target = self
        menu.addItem(addHostItem)

        menu.addItem(NSMenuItem.separator())

        // Actions
        let reloadItem = NSMenuItem(title: "Reload State", action: #selector(handleReload), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let quitItem = NSMenuItem(title: "Quit SSHGuard", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Update badge if pending hosts exist
        if let button = statusItem?.button {
            button.title = stateManager.pendingCount > 0 ? " (\(stateManager.pendingCount))" : ""
        }
    }

    /// Create menu item for a known host
    private func createHostItem(_ host: Host) -> NSMenuItem {
        // Show hostname and IP: "🟢 proxmox02 (10.71.1.8)"
        let displayText: String
        if let hostname = host.hostname, hostname != host.ip {
            displayText = "\(host.state.icon) \(hostname) (\(host.ip))"
        } else {
            displayText = "\(host.state.icon) \(host.ip)"
        }

        let item = NSMenuItem(
            title: displayText,
            action: #selector(handleHostClick(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = host.id
        item.toolTip = host.note ?? host.sshTarget

        // Submenu for additional actions
        let submenu = NSMenu()

        // State options
        for state in SSHState.allCases {
            let stateItem = NSMenuItem(
                title: "\(state.icon) \(state.label)",
                action: #selector(handleStateChange(_:)),
                keyEquivalent: ""
            )
            stateItem.target = self
            stateItem.representedObject = (host.id, state)
            stateItem.state = (host.state == state) ? .on : .off
            submenu.addItem(stateItem)
        }

        submenu.addItem(NSMenuItem.separator())

        // Edit host
        let editItem = NSMenuItem(
            title: "Edit...",
            action: #selector(handleEditHost(_:)),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.representedObject = host.id
        submenu.addItem(editItem)

        // Copy SSH command
        let copyItem = NSMenuItem(
            title: "Copy SSH Command",
            action: #selector(handleCopySSH(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        copyItem.representedObject = host.sshTarget
        submenu.addItem(copyItem)

        submenu.addItem(NSMenuItem.separator())

        // Remove host
        let removeItem = NSMenuItem(
            title: "Remove Host...",
            action: #selector(handleRemoveHost(_:)),
            keyEquivalent: ""
        )
        removeItem.target = self
        removeItem.representedObject = host.id
        submenu.addItem(removeItem)

        item.submenu = submenu
        return item
    }

    /// Create menu item for a pending host
    private func createPendingHostItem(_ pending: PendingHost) -> NSMenuItem {
        let item = NSMenuItem(
            title: "  ? \(pending.displayName)",
            action: nil,
            keyEquivalent: ""
        )

        // Submenu with authorization options
        let submenu = NSMenu()

        let allowItem = NSMenuItem(
            title: "🟢 Allow",
            action: #selector(handleAuthorizePending(_:)),
            keyEquivalent: ""
        )
        allowItem.target = self
        allowItem.representedObject = (pending.ip, SSHState.allowed)
        submenu.addItem(allowItem)

        let askItem = NSMenuItem(
            title: "⚪ Ask",
            action: #selector(handleAuthorizePending(_:)),
            keyEquivalent: ""
        )
        askItem.target = self
        askItem.representedObject = (pending.ip, SSHState.ask)
        submenu.addItem(askItem)

        let blockItem = NSMenuItem(
            title: "🔴 Block",
            action: #selector(handleAuthorizePending(_:)),
            keyEquivalent: ""
        )
        blockItem.target = self
        blockItem.representedObject = (pending.ip, SSHState.blocked)
        submenu.addItem(blockItem)

        submenu.addItem(NSMenuItem.separator())

        let dismissItem = NSMenuItem(
            title: "Dismiss",
            action: #selector(handleDismissPending(_:)),
            keyEquivalent: ""
        )
        dismissItem.target = self
        dismissItem.representedObject = pending.ip
        submenu.addItem(dismissItem)

        item.submenu = submenu
        return item
    }

    // MARK: - Menu Actions

    @objc private func handleHostClick(_ sender: NSMenuItem) {
        guard let hostID = sender.representedObject as? String else { return }

        Task {
            await stateManager.cycleHostState(id: hostID)
            updateMenu()
        }
    }

    @objc private func handleStateChange(_ sender: NSMenuItem) {
        guard let (hostID, newState) = sender.representedObject as? (String, SSHState) else { return }

        Task {
            await stateManager.updateHostState(id: hostID, newState: newState)
            updateMenu()
        }
    }

    @objc private func handleCopySSH(_ sender: NSMenuItem) {
        guard let sshTarget = sender.representedObject as? String else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("ssh \(sshTarget)", forType: .string)

        // TODO: Show brief notification that command was copied
    }

    @objc private func handleRemoveHost(_ sender: NSMenuItem) {
        guard let hostID = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = "Remove Host?"
        alert.informativeText = "This will remove the host from SSHGuard. SSH attempts will be blocked until re-authorized."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                await stateManager.removeHost(id: hostID)
                updateMenu()
            }
        }
    }

    @objc private func handleAuthorizePending(_ sender: NSMenuItem) {
        guard let (ip, state) = sender.representedObject as? (String, SSHState) else { return }

        Task {
            await stateManager.authorizePendingHost(ip: ip, state: state)
            updateMenu()
        }
    }

    @objc private func handleDismissPending(_ sender: NSMenuItem) {
        guard let ip = sender.representedObject as? String else { return }

        Task {
            await stateManager.removePendingHost(ip: ip)
            updateMenu()
        }
    }

    @objc private func handleReload() {
        Task {
            await stateManager.reload()
            updateMenu()
        }
    }

    @objc private func handleAddHost() {
        let windowController = HostEditorWindowController(
            host: nil,
            stateManager: stateManager,
            onSave: { [weak self] in
                self?.updateMenu()
            }
        )
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleEditHost(_ sender: NSMenuItem) {
        guard let hostID = sender.representedObject as? String,
              let host = stateManager.state.findHost(byID: hostID) else { return }

        let windowController = HostEditorWindowController(
            host: host,
            stateManager: stateManager,
            onSave: { [weak self] in
                self?.updateMenu()
            }
        )
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
