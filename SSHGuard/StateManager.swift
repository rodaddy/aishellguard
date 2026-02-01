import Foundation

/// Manages reading/writing SSH permissions state file
@MainActor
class StateManager: ObservableObject {
    // MARK: - Published State

    @Published var state: SSHPermissionsState
    @Published var error: String?

    // MARK: - Configuration

    let stateFilePath: URL
    private let fileManager = FileManager.default

    /// ISO 8601 date formatter with fractional seconds (for writing)
    private static let dateFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO 8601 date formatter without fractional seconds (for reading legacy)
    private static let dateFormatterBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// JSON encoder with custom date formatting
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(StateManager.dateFormatterWithFractional.string(from: date))
        }
        return encoder
    }()

    /// JSON decoder with flexible date parsing (handles with/without fractional seconds)
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try with fractional seconds first, then without
            if let date = StateManager.dateFormatterWithFractional.date(from: dateString) {
                return date
            }
            if let date = StateManager.dateFormatterBasic.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        return decoder
    }()

    // MARK: - Initialization

    init(stateFilePath: URL? = nil) {
        // Use provided path, or get from settings (which auto-detects PAI vs default)
        self.stateFilePath = stateFilePath ?? AppSettings.stateFilePath

        // Load or create initial state
        if let loadedState = Self.loadState(from: self.stateFilePath, decoder: Self.jsonDecoder) {
            self.state = loadedState
        } else {
            // Create empty state
            self.state = SSHPermissionsState()
            // Try to save immediately
            Task {
                await self.save()
            }
        }
    }

    // MARK: - File Operations

    /// Load state from disk
    private static func loadState(from url: URL, decoder: JSONDecoder) -> SSHPermissionsState? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let state = try decoder.decode(SSHPermissionsState.self, from: data)
            return state
        } catch {
            print("Error loading state file: \(error)")
            return nil
        }
    }

    /// Save state to disk (atomic write)
    func save() async {
        do {
            // Ensure directory exists
            let directory = stateFilePath.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            // Update lastUpdated timestamp
            state.lastUpdated = Date()

            // Encode to JSON
            let data = try Self.jsonEncoder.encode(state)

            // Atomic write (write to temp, then rename)
            let tempPath = stateFilePath.appendingPathExtension("tmp")
            try data.write(to: tempPath, options: .atomic)

            // Replace original file
            if fileManager.fileExists(atPath: stateFilePath.path) {
                try fileManager.removeItem(at: stateFilePath)
            }
            try fileManager.moveItem(at: tempPath, to: stateFilePath)

            error = nil
        } catch {
            self.error = "Failed to save state: \(error.localizedDescription)"
            print("Save error: \(error)")
        }
    }

    /// Reload state from disk
    func reload() async {
        if let loadedState = Self.loadState(from: stateFilePath, decoder: Self.jsonDecoder) {
            state = loadedState
            error = nil
        } else {
            error = "Failed to reload state file"
        }
    }

    // MARK: - Host Management

    /// Add or update a host
    func upsertHost(_ host: Host) async {
        if let index = state.hosts.firstIndex(where: { $0.id == host.id }) {
            state.hosts[index] = host
        } else {
            state.hosts.append(host)
        }
        await save()
    }

    /// Remove a host by ID
    func removeHost(id: String) async {
        state.hosts.removeAll { $0.id == id }
        await save()
    }

    /// Update host state
    func updateHostState(id: String, newState: SSHState) async {
        guard let index = state.hosts.firstIndex(where: { $0.id == id }) else { return }
        state.hosts[index].state = newState
        await save()
    }

    /// Cycle host state (blocked → ask → allowed → blocked)
    func cycleHostState(id: String) async {
        guard let index = state.hosts.firstIndex(where: { $0.id == id }) else { return }
        state.hosts[index].state = state.hosts[index].state.next
        await save()
    }

    // MARK: - Pending Host Management

    /// Add pending host
    func addPendingHost(_ pendingHost: PendingHost) async {
        // Don't add duplicates
        guard !state.pending.contains(where: { $0.ip == pendingHost.ip }) else { return }
        state.pending.append(pendingHost)
        await save()
    }

    /// Remove pending host
    func removePendingHost(ip: String) async {
        state.pending.removeAll { $0.ip == ip }
        await save()
    }

    /// Promote pending host to authorized host
    func authorizePendingHost(ip: String, state: SSHState) async {
        guard let pending = self.state.pending.first(where: { $0.ip == ip }) else { return }

        // Create new host from pending
        let newHost = Host(
            id: "host-\(UUID().uuidString.prefix(8))",
            ip: pending.ip,
            user: pending.user ?? "rico",
            state: state,
            note: "Added from pending queue"
        )

        // Add to hosts
        await upsertHost(newHost)

        // Remove from pending
        await removePendingHost(ip: ip)
    }

    // MARK: - Queries

    /// Get all hosts sorted by last used (recent first)
    var sortedHosts: [Host] {
        state.hosts.sorted { (lhs, rhs) in
            if let lhsDate = lhs.lastUsed, let rhsDate = rhs.lastUsed {
                return lhsDate > rhsDate
            } else if lhs.lastUsed != nil {
                return true
            } else if rhs.lastUsed != nil {
                return false
            } else {
                return lhs.displayName < rhs.displayName
            }
        }
    }

    /// Get hosts by state
    func hosts(withState state: SSHState) -> [Host] {
        self.state.hosts.filter { $0.state == state }
    }

    /// Count of pending hosts (for badge)
    var pendingCount: Int {
        state.pending.count
    }
}
