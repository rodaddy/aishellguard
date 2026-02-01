import Foundation

/// App settings stored in UserDefaults
enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let stateFilePath = "stateFilePath"
        static let launchAtLogin = "launchAtLogin"
    }

    // MARK: - Default Values

    /// Default state file path for general users
    static let defaultStateFilePath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sshguard/hosts.json")
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

            // Default to generic sshguard path
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
}
