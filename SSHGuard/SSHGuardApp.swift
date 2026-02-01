import SwiftUI

/// Main application entry point
@main
struct SSHGuardApp: App {
    @StateObject private var stateManager = StateManager()
    @StateObject private var menuBarManager: MenuBarManager

    init() {
        let stateManager = StateManager()
        _stateManager = StateObject(wrappedValue: stateManager)
        _menuBarManager = StateObject(wrappedValue: MenuBarManager(stateManager: stateManager))
    }

    var body: some Scene {
        // Menu bar app - no window needed
        MenuBarExtra("SSHGuard", systemImage: "network") {
            EmptyView()
        }
        .menuBarExtraStyle(.window)

        // Settings window (optional, for future use)
        Settings {
            SettingsView(stateManager: stateManager)
        }
    }
}

/// Settings view (placeholder for future features)
struct SettingsView: View {
    @ObservedObject var stateManager: StateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSHGuard Settings")
                .font(.title)

            Divider()

            LabeledContent("State File:") {
                Text(stateManager.stateFilePath.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            LabeledContent("Total Hosts:") {
                Text("\(stateManager.state.hosts.count)")
            }

            LabeledContent("Pending Hosts:") {
                Text("\(stateManager.pendingCount)")
            }

            Divider()

            if let error = stateManager.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()

            HStack {
                Button("Reload State") {
                    Task {
                        await stateManager.reload()
                    }
                }

                Spacer()

                Button("Open State File") {
                    NSWorkspace.shared.open(stateManager.stateFilePath)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
}
