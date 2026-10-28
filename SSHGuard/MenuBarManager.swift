import AppKit
import SwiftUI

/// Manages the menu bar status item and popover
@MainActor
class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let stateManager: StateManager

    /// Event monitor for detecting clicks outside the popover
    private var eventMonitor: Any?

    init(stateManager: StateManager) {
        self.stateManager = stateManager
        setupMenuBar()
        setupPopover()

        // Listen for icon style changes
        NotificationCenter.default.addObserver(
            forName: .menuBarIconChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.updateMenuBarIcon()
        }
    }

    /// Create and configure the menu bar item
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateMenuBarIcon()
        updateBadge()
    }

    /// Create and configure the popover with SwiftUI content
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient
        popover?.animates = true

        let popoverView = MenuBarPopoverView(
            stateManager: stateManager,
            onManageHosts: { [weak self] in
                self?.closePopover()
                self?.handleManageHosts()
            },
            onAddHost: { [weak self] in
                self?.closePopover()
                self?.handleAddHost()
            },
            onPreferences: { [weak self] in
                self?.closePopover()
                self?.handlePreferences()
            },
            onQuit: { [weak self] in
                self?.closePopover()
                self?.handleQuit()
            }
        )

        popover?.contentViewController = NSHostingController(rootView: popoverView)
    }

    /// Toggle popover visibility
    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    /// Show the popover anchored to the status item
    private func showPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Add event monitor to close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    /// Close the popover
    private func closePopover() {
        popover?.performClose(nil)

        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Update the badge count for pending hosts
    func updateBadge() {
        if let button = statusItem?.button {
            button.title = stateManager.pendingCount > 0 ? " (\(stateManager.pendingCount))" : ""
        }
    }

    /// Update menu bar icon based on user preference
    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let style = AppSettings.menuBarIconStyle
        let resourceName: String

        switch style {
        case .globeDark:
            resourceName = "MenuBar-Globe-Dark-18"
        case .globeLight:
            resourceName = "MenuBar-Globe-Light-18"
        case .padlockDark:
            resourceName = "MenuBar-Padlock-Dark-18"
        case .padlockLight:
            resourceName = "MenuBar-Padlock-Light-18"
        case .systemSymbol:
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "AIShell Guard")
            return
        }

        if let iconURL = Bundle.module.url(forResource: resourceName, withExtension: "png"),
           let iconImage = NSImage(contentsOf: iconURL) {
            iconImage.size = NSSize(width: 18, height: 18)
            button.image = iconImage
        }
    }

    // MARK: - Window Actions

    private func handleManageHosts() {
        ManageHostsWindowController.showOrBring(stateManager: stateManager) { [weak self] in
            self?.updateBadge()
        }
    }

    private func handleAddHost() {
        let windowController = HostEditorWindowController(
            host: nil,
            stateManager: stateManager,
            onSave: { [weak self] in
                self?.updateBadge()
            }
        )
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handlePreferences() {
        Task { @MainActor in
            PreferencesWindowController.showOrBring(stateManager: stateManager)
        }
    }

    private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
