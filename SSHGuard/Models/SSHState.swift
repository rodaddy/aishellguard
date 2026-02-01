import Foundation

/// Authorization state for an SSH host
enum SSHState: String, Codable, CaseIterable {
    case allowed = "allowed"   // 🟢 Green - SSH permitted
    case ask = "ask"           // ⚪ Grey - Requires confirmation
    case blocked = "blocked"   // 🔴 Red - SSH explicitly denied

    /// Icon representation for menu display
    var icon: String {
        switch self {
        case .allowed: return "🟢"
        case .ask: return "⚪"
        case .blocked: return "🔴"
        }
    }

    /// Display label for menu
    var label: String {
        switch self {
        case .allowed: return "Allowed"
        case .ask: return "Ask"
        case .blocked: return "Blocked"
        }
    }

    /// Next state in cycle (for click-to-toggle)
    var next: SSHState {
        switch self {
        case .blocked: return .ask
        case .ask: return .allowed
        case .allowed: return .blocked
        }
    }
}
