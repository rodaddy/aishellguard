import SwiftUI
import AppKit

/// Window controller for Preferences
class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    static var shared: PreferencesWindowController?

    convenience init(stateManager: StateManager) {
        let hostingController = NSHostingController(
            rootView: PreferencesView(stateManager: stateManager)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SSHGuard Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 320))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.init(window: window)
        window.delegate = self
    }

    static func showOrBring(stateManager: StateManager) {
        if let existing = shared, existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
        } else {
            shared = PreferencesWindowController(stateManager: stateManager)
            shared?.showWindow(nil)
        }

        WindowActivation.activate(window: shared?.window)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            shared?.window?.level = .normal
        }
    }

    func windowWillClose(_ notification: Notification) {
        WindowActivation.windowClosed()
    }
}

/// Preferences view with tabs
struct PreferencesView: View {
    @ObservedObject var stateManager: StateManager
    @State private var selectedIconStyle: MenuBarIconStyle = AppSettings.menuBarIconStyle
    @State private var showInDock: Bool = AppSettings.showInDock

    var body: some View {
        TabView {
            GeneralPreferencesTab(
                showInDock: $showInDock,
                stateManager: stateManager
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            AppearancePreferencesTab(
                selectedIconStyle: $selectedIconStyle
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
        }
        .padding()
        .onChange(of: selectedIconStyle) { newValue in
            AppSettings.menuBarIconStyle = newValue
            NotificationCenter.default.post(name: .menuBarIconChanged, object: nil)
        }
        .onChange(of: showInDock) { newValue in
            AppSettings.showInDock = newValue
        }
    }
}

/// General preferences tab
struct GeneralPreferencesTab: View {
    @Binding var showInDock: Bool
    @ObservedObject var stateManager: StateManager
    @State private var showFileChooser = false
    @State private var enableHMAC: Bool = AppSettings.enableHMAC
    @State private var originalDockSetting: Bool = AppSettings.showInDock

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Show in Dock", isOn: $showInDock)
                    .help("Show SSHGuard icon in the Dock (requires restart)")
                if showInDock != originalDockSetting {
                    Button("⚡ Restart to Apply") {
                        restartApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            Section("Security") {
                Toggle("Enable HMAC Signing", isOn: $enableHMAC)
                    .help("Sign state file to prevent tampering. Disable during development.")
                    .onChange(of: enableHMAC) { newValue in
                        AppSettings.enableHMAC = newValue
                    }
                if !enableHMAC {
                    Text("⚠️ File tampering protection disabled")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("State File") {
                LabeledContent("Location:") {
                    Text(stateManager.stateFilePath.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack {
                    Button("Change...") {
                        showFileChooser = true
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(
                            stateManager.stateFilePath.path,
                            inFileViewerRootedAtPath: ""
                        )
                    }
                }
            }

            Section("Statistics") {
                LabeledContent("Hosts:") { Text("\(stateManager.state.hosts.count)") }
                LabeledContent("Pending:") { Text("\(stateManager.pendingCount)") }
                LabeledContent("Groups:") { Text("\(stateManager.state.sortedGroups().count)") }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $showFileChooser, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                AppSettings.stateFilePath = url
            }
        }
    }

    /// Restart the application
    private func restartApp() {
        guard let executableURL = Bundle.main.executableURL else {
            print("Could not get executable URL")
            return
        }

        // Launch a new instance
        let task = Process()
        task.executableURL = executableURL
        task.arguments = []

        do {
            try task.run()
        } catch {
            print("Failed to relaunch: \(error)")
            return
        }

        // Terminate current instance after brief delay to let new one start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
}

/// Appearance preferences tab with icon preview
struct AppearancePreferencesTab: View {
    @Binding var selectedIconStyle: MenuBarIconStyle

    var body: some View {
        Form {
            Section("Menu Bar Icon") {
                Picker("Style:", selection: $selectedIconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        HStack {
                            iconPreview(for: style)
                                .frame(width: 18, height: 18)
                            Text(style.displayName)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                HStack {
                    Text("Preview:")
                    Spacer()
                    iconPreview(for: selectedIconStyle)
                        .frame(width: 32, height: 32)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    func iconPreview(for style: MenuBarIconStyle) -> some View {
        switch style {
        case .globeDark:
            if let url = Bundle.module.url(forResource: "MenuBar-Globe-Dark-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
            }
        case .globeLight:
            if let url = Bundle.module.url(forResource: "MenuBar-Globe-Light-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
            }
        case .padlockDark:
            if let url = Bundle.module.url(forResource: "MenuBar-Padlock-Dark-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "lock.fill")
            }
        case .padlockLight:
            if let url = Bundle.module.url(forResource: "MenuBar-Padlock-Light-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "lock.fill")
            }
        case .systemSymbol:
            Image(systemName: "lock.shield")
        }
    }
}
