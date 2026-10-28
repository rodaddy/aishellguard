import Foundation
import AppKit

/// Menu bar icon styles
enum MenuBarIconStyle: String, CaseIterable {
    case globeDark = "globeDark"
    case globeLight = "globeLight"
    case padlockDark = "padlockDark"
    case padlockLight = "padlockLight"
    case systemSymbol = "systemSymbol"

    var displayName: String {
        switch self {
        case .globeDark: return "Globe (Dark)"
        case .globeLight: return "Globe (Light)"
        case .padlockDark: return "Padlock (Dark)"
        case .padlockLight: return "Padlock (Light)"
        case .systemSymbol: return "System Symbol"
        }
    }
}

/// App settings stored in UserDefaults
enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let stateFilePath = "stateFilePath"
        static let launchAtLogin = "launchAtLogin"
        static let menuBarIconStyle = "menuBarIconStyle"
        static let showInDock = "showInDock"
    }

    // MARK: - Default Values

    /// Default state file path for general users
    static let defaultStateFilePath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/aishellguard/hosts.json")
    }()

    /// Alternative path for PAI users (checked on first run)
    static let paiStateFilePath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/pai/infrastructure/ssh-permissions.json")
    }()

    // MARK: - State File Path

    /// Get the configured state file path
    static var stateFilePath: URL {
        get {
            if let savedPath = defaults.string(forKey: Keys.stateFilePath) {
                return URL(fileURLWithPath: savedPath)
            }

            // First run: check if PAI path exists, use it if so
            if FileManager.default.fileExists(atPath: paiStateFilePath.path) {
                // User has PAI infrastructure, use that
                defaults.set(paiStateFilePath.path, forKey: Keys.stateFilePath)
                return paiStateFilePath
            }

            // Default to generic AIShell Guard path
            return defaultStateFilePath
        }
        set {
            defaults.set(newValue.path, forKey: Keys.stateFilePath)
        }
    }

    /// Check if using custom path (not default)
    static var isUsingCustomPath: Bool {
        defaults.string(forKey: Keys.stateFilePath) != nil
    }

    /// Reset to default path
    static func resetToDefaultPath() {
        defaults.removeObject(forKey: Keys.stateFilePath)
    }

    // MARK: - Launch at Login

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    // MARK: - Menu Bar Icon Style

    static var menuBarIconStyle: MenuBarIconStyle {
        get {
            let raw = defaults.string(forKey: Keys.menuBarIconStyle) ?? MenuBarIconStyle.globeDark.rawValue
            return MenuBarIconStyle(rawValue: raw) ?? .globeDark
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.menuBarIconStyle)
        }
    }

    // MARK: - HMAC Signing

    static var enableHMAC: Bool {
        get { defaults.bool(forKey: "enableHMAC") }
        set { defaults.set(newValue, forKey: "enableHMAC") }
    }

    // MARK: - Show in Dock

    static var showInDock: Bool {
        get { defaults.bool(forKey: Keys.showInDock) }
        set {
            defaults.set(newValue, forKey: Keys.showInDock)
            // Note: Changing activation policy while windows are open is problematic
            // We'll apply on next app launch instead
            // User sees a note that restart is required
        }
    }

    /// Apply dock visibility setting (call on app launch only)
    static func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
}
