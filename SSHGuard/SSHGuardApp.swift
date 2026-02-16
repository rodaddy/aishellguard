import SwiftUI
import AppKit

/// Main application entry point
@main
struct AIShellGuardApp: App {
    @StateObject private var stateManager = StateManager()
    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var apiServer: APIServer
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let stateManager = StateManager()
        _stateManager = StateObject(wrappedValue: stateManager)
        _menuBarManager = StateObject(wrappedValue: MenuBarManager(stateManager: stateManager))
        _apiServer = StateObject(wrappedValue: APIServer(stateManager: stateManager))
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
        // Apply user preference for dock visibility
        AppSettings.applyDockVisibility()
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

/// Settings view with tabbed preferences
struct SettingsView: View {
    @ObservedObject var stateManager: StateManager
    @State private var selectedIconStyle: MenuBarIconStyle = AppSettings.menuBarIconStyle
    @State private var showInDock: Bool = AppSettings.showInDock

    var body: some View {
        TabView {
            // General Tab
            GeneralSettingsTab(
                selectedIconStyle: $selectedIconStyle,
                showInDock: $showInDock,
                stateManager: stateManager
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // Appearance Tab
            AppearanceSettingsTab(
                selectedIconStyle: $selectedIconStyle
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
        }
        .frame(width: 450, height: 300)
        .onChange(of: selectedIconStyle) { newValue in
            AppSettings.menuBarIconStyle = newValue
            NotificationCenter.default.post(name: .menuBarIconChanged, object: nil)
        }
        .onChange(of: showInDock) { newValue in
            AppSettings.showInDock = newValue
        }
    }
}

/// General settings tab
struct GeneralSettingsTab: View {
    @Binding var selectedIconStyle: MenuBarIconStyle
    @Binding var showInDock: Bool
    @ObservedObject var stateManager: StateManager
    @State private var showFileChooser = false

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Show in Dock", isOn: $showInDock)
                    .help("Show AIShell Guard icon in the Dock")
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
        .padding()
        .fileImporter(isPresented: $showFileChooser, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                AppSettings.stateFilePath = url
            }
        }
    }
}

/// Appearance settings tab with icon preview
struct AppearanceSettingsTab: View {
    @Binding var selectedIconStyle: MenuBarIconStyle

    var body: some View {
        Form {
            Section("Menu Bar Icon") {
                Picker("Style:", selection: $selectedIconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        HStack {
                            iconPreview(for: style)
                                .frame(width: 20, height: 20)
                            Text(style.rawValue)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                // Large preview
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
        .padding()
    }

    @ViewBuilder
    func iconPreview(for style: MenuBarIconStyle) -> some View {
        switch style {
        case .globeDark:
            if let url = Bundle.module.url(forResource: "MenuBar-Globe-Dark-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
            }
        case .globeLight:
            if let url = Bundle.module.url(forResource: "MenuBar-Globe-Light-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
            }
        case .padlockDark:
            if let url = Bundle.module.url(forResource: "MenuBar-Padlock-Dark-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
            }
        case .padlockLight:
            if let url = Bundle.module.url(forResource: "MenuBar-Padlock-Light-18", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
            }
        case .systemSymbol:
            Image(systemName: "lock.shield")
        }
    }
}
