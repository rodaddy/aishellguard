import SwiftUI
import AppKit

/// Main application entry point
@main
struct SSHGuardApp: App {
    @StateObject private var stateManager = StateManager()
    @StateObject private var menuBarManager: MenuBarManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let stateManager = StateManager()
        _stateManager = StateObject(wrappedValue: stateManager)
        _menuBarManager = StateObject(wrappedValue: MenuBarManager(stateManager: stateManager))
    }

    var body: some Scene {
        // Settings window only - menu bar is handled by MenuBarManager (AppKit)
        Settings {
            SettingsView(stateManager: stateManager)
        }
    }
}

/// App delegate to handle window focus for menu bar apps
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as accessory (menu bar only, no dock icon)
        // When windows open, we temporarily become regular app
    }
}

/// Helper to properly activate windows from menu bar apps
enum WindowActivation {
    /// Activate app and bring window to front with keyboard focus
    static func activate(window: NSWindow?) {
        guard let window = window else { return }

        // Temporarily become a regular app (shows in dock, can receive focus)
        NSApp.setActivationPolicy(.regular)

        // Activate and focus
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Return to accessory after a delay (hides from dock again)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only go back to accessory if no windows are visible
            let hasVisibleWindows = NSApp.windows.contains { $0.isVisible && !$0.title.isEmpty }
            if !hasVisibleWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    /// Call when closing the last window to return to accessory mode
    static func windowClosed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasVisibleWindows = NSApp.windows.contains { $0.isVisible && $0.title.count > 0 }
            if !hasVisibleWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

/// Settings view with state file path configuration
struct SettingsView: View {
    @ObservedObject var stateManager: StateManager
    @State private var showFileChooser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSHGuard Settings")
                .font(.title)

            Divider()

            // State file path with change button
            VStack(alignment: .leading, spacing: 8) {
                Text("Hosts File Location:")
                    .font(.headline)

                HStack {
                    Text(stateManager.stateFilePath.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Change...") {
                        showFileChooser = true
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

                Text("Default: ~/.config/sshguard/hosts.json")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Stats
            HStack(spacing: 24) {
                LabeledContent("Hosts:") {
                    Text("\(stateManager.state.hosts.count)")
                        .fontWeight(.medium)
                }

                LabeledContent("Pending:") {
                    Text("\(stateManager.pendingCount)")
                        .fontWeight(.medium)
                }
            }

            if let error = stateManager.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }

            Spacer()

            // Actions
            HStack {
                Button("Reload") {
                    Task {
                        await stateManager.reload()
                    }
                }

                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(
                        stateManager.stateFilePath.path,
                        inFileViewerRootedAtPath: stateManager.stateFilePath.deletingLastPathComponent().path
                    )
                }

                Spacer()

                Button("Open File") {
                    NSWorkspace.shared.open(stateManager.stateFilePath)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 320)
        .fileImporter(
            isPresented: $showFileChooser,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    AppSettings.stateFilePath = url
                    // Note: requires app restart to use new path
                }
            case .failure(let error):
                print("File selection failed: \(error)")
            }
        }
    }
}
