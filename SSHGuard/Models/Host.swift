import Foundation

/// Represents a known SSH host with authorization state
struct Host: Codable, Identifiable, Equatable {
    let id: String
    var hostname: String?
    var ip: String
    var user: String
    var state: SSHState
    var note: String?
    var lastUsed: Date?
    var tags: [String]

    // Custom decoding to handle missing 'tags' field gracefully
    enum CodingKeys: String, CodingKey {
        case id, hostname, ip, user, state, note, lastUsed, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        hostname = try container.decodeIfPresent(String.self, forKey: .hostname)
        ip = try container.decode(String.self, forKey: .ip)
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? NSUserName()
        state = try container.decodeIfPresent(SSHState.self, forKey: .state) ?? .ask
        note = try container.decodeIfPresent(String.self, forKey: .note)
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    init(
        id: String,
        hostname: String? = nil,
        ip: String,
        user: String = NSUserName(),
        state: SSHState = .ask,
        note: String? = nil,
        lastUsed: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.hostname = hostname
        self.ip = ip
        self.user = user
        self.state = state
        self.note = note
        self.lastUsed = lastUsed
        self.tags = tags
    }

    /// Display name for menu (hostname or IP)
    var displayName: String {
        hostname ?? ip
    }

    /// Full SSH connection string
    var sshTarget: String {
        "\(user)@\(ip)"
    }

    /// One-line description for tooltip
    var description: String {
        var parts: [String] = [displayName]
        if let note = note {
            parts.append(note)
        }
        return parts.joined(separator: " - ")
    }
}

/// Represents a pending (unknown) host awaiting authorization
struct PendingHost: Codable, Identifiable, Equatable {
    var id: String { ip } // Use IP as stable ID
    let ip: String
    var user: String?
    let detectedAt: Date
    var attemptedBy: String

    init(ip: String, user: String? = nil, detectedAt: Date = Date(), attemptedBy: String = "claude-code") {
        self.ip = ip
        self.user = user
        self.detectedAt = detectedAt
        self.attemptedBy = attemptedBy
    }

    /// Display name for notification
    var displayName: String {
        if let user = user {
            return "\(user)@\(ip)"
        }
        return ip
    }
}

/// Root structure matching JSON state file
struct SSHPermissionsState: Codable {
    var version: String
    var machine: String
    var lastUpdated: Date
    var hosts: [Host]
    var pending: [PendingHost]
    var groupOrder: [String]  // Custom group ordering (first tag)
    var signature: String?  // HMAC-SHA256 of hosts array

    init(
        version: String = "1.0",
        machine: String = ProcessInfo.processInfo.hostName,
        lastUpdated: Date = Date(),
        hosts: [Host] = [],
        pending: [PendingHost] = [],
        groupOrder: [String] = [],
        signature: String? = nil
    ) {
        self.version = version
        self.machine = machine
        self.lastUpdated = lastUpdated
        self.hosts = hosts
        self.pending = pending
        self.groupOrder = groupOrder
        self.signature = signature
    }

    /// Get groups in custom order (groups not in order appear at end alphabetically)
    func sortedGroups() -> [String] {
        let allGroups = Set(hosts.map { $0.tags.first ?? "ungrouped" })
        var result: [String] = []

        // First add groups in custom order
        for group in groupOrder {
            if allGroups.contains(group) {
                result.append(group)
            }
        }

        // Then add remaining groups alphabetically
        let remaining = allGroups.subtracting(Set(groupOrder)).sorted()
        result.append(contentsOf: remaining)

        return result
    }

    /// Find host by IP or hostname
    func findHost(byIPOrHostname target: String) -> Host? {
        hosts.first { $0.ip == target || $0.hostname == target }
    }

    /// Find host by ID
    func findHost(byID id: String) -> Host? {
        hosts.first { $0.id == id }
    }
}
