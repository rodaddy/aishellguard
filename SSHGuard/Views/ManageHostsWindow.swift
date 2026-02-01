import SwiftUI
import AppKit

/// Window controller for full host management
class ManageHostsWindowController: NSWindowController {
    static var shared: ManageHostsWindowController?

    convenience init(stateManager: StateManager, onUpdate: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: ManageHostsView(stateManager: stateManager, onUpdate: onUpdate)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SSHGuard - Manage Hosts"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 500))
        window.minSize = NSSize(width: 500, height: 400)
        window.center()

        self.init(window: window)
    }

    static func showOrBring(stateManager: StateManager, onUpdate: @escaping () -> Void) {
        if let existing = shared, existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
        } else {
            shared = ManageHostsWindowController(stateManager: stateManager, onUpdate: onUpdate)
            shared?.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Full host management view
struct ManageHostsView: View {
    @ObservedObject var stateManager: StateManager
    let onUpdate: () -> Void

    @State private var selectedHostID: String?
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var hostToEdit: Host?

    var body: some View {
        HSplitView {
            // Left: Host list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search hosts...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))

                Divider()

                // Host list grouped
                List(selection: $selectedHostID) {
                    ForEach(groupedHosts, id: \.key) { group, hosts in
                        Section(header: Text(group.uppercased()).font(.caption).foregroundColor(.secondary)) {
                            ForEach(hosts) { host in
                                HostRowView(host: host)
                                    .tag(host.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Toolbar
                HStack {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .help("Add Host")

                    Button(action: editSelected) {
                        Image(systemName: "pencil")
                    }
                    .disabled(selectedHostID == nil)
                    .help("Edit Host")

                    Button(action: deleteSelected) {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedHostID == nil)
                    .help("Delete Host")

                    Spacer()

                    Text("\(stateManager.state.hosts.count) hosts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .frame(minWidth: 250, idealWidth: 300)

            // Right: Details
            if let hostID = selectedHostID,
               let host = stateManager.state.findHost(byID: hostID) {
                HostDetailView(
                    host: host,
                    stateManager: stateManager,
                    onEdit: { hostToEdit = host },
                    onUpdate: onUpdate
                )
            } else {
                VStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a host")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            HostEditorSheet(host: nil, stateManager: stateManager) {
                onUpdate()
            }
        }
        .sheet(item: $hostToEdit) { host in
            HostEditorSheet(host: host, stateManager: stateManager) {
                onUpdate()
            }
        }
    }

    private var groupedHosts: [(key: String, value: [Host])] {
        let filtered = stateManager.state.hosts.filter { host in
            searchText.isEmpty ||
            host.displayName.localizedCaseInsensitiveContains(searchText) ||
            host.ip.contains(searchText) ||
            host.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }

        let grouped = Dictionary(grouping: filtered) { host -> String in
            host.tags.first ?? "ungrouped"
        }

        return grouped.sorted { lhs, rhs in
            if lhs.key == "ungrouped" { return false }
            if rhs.key == "ungrouped" { return true }
            return lhs.key < rhs.key
        }
    }

    private func editSelected() {
        if let id = selectedHostID,
           let host = stateManager.state.findHost(byID: id) {
            hostToEdit = host
        }
    }

    private func deleteSelected() {
        guard let id = selectedHostID else { return }
        Task {
            await stateManager.removeHost(id: id)
            selectedHostID = nil
            onUpdate()
        }
    }
}

/// Row in host list
struct HostRowView: View {
    let host: Host

    var body: some View {
        HStack {
            Text(host.state.icon)
            VStack(alignment: .leading) {
                Text(host.displayName)
                    .fontWeight(.medium)
                Text(host.ip)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Host detail panel
struct HostDetailView: View {
    let host: Host
    @ObservedObject var stateManager: StateManager
    let onEdit: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(host.state.icon)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(host.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(host.sshTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Edit") { onEdit() }
            }

            Divider()

            // State picker
            HStack {
                Text("State:")
                Picker("", selection: Binding(
                    get: { host.state },
                    set: { newState in
                        Task {
                            await stateManager.updateHostState(id: host.id, newState: newState)
                            onUpdate()
                        }
                    }
                )) {
                    ForEach(SSHState.allCases, id: \.self) { state in
                        Text("\(state.icon) \(state.label)").tag(state)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // Details
            Form {
                LabeledContent("ID:") { Text(host.id).font(.system(.body, design: .monospaced)) }
                LabeledContent("IP:") { Text(host.ip).font(.system(.body, design: .monospaced)) }
                LabeledContent("User:") { Text(host.user) }
                LabeledContent("Tags:") {
                    if host.tags.isEmpty {
                        Text("None").foregroundColor(.secondary)
                    } else {
                        HStack {
                            ForEach(host.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                if let note = host.note {
                    LabeledContent("Note:") { Text(note) }
                }
                if let lastUsed = host.lastUsed {
                    LabeledContent("Last Used:") { Text(lastUsed, style: .relative) }
                }
            }
            .formStyle(.grouped)

            Spacer()

            // Actions
            HStack {
                Button("Copy SSH Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("ssh \(host.sshTarget)", forType: .string)
                }

                Button("Connect (SSH)") {
                    // Open terminal with SSH command
                    let script = "tell app \"Terminal\" to do script \"ssh \(host.sshTarget)\""
                    NSAppleScript(source: script)?.executeAndReturnError(nil)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Sheet for adding/editing host
struct HostEditorSheet: View {
    let existingHost: Host?
    @ObservedObject var stateManager: StateManager
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var id: String = ""
    @State private var hostname: String = ""
    @State private var ip: String = ""
    @State private var user: String = "rico"
    @State private var state: SSHState = .ask
    @State private var note: String = ""
    @State private var tagsText: String = ""

    init(host: Host?, stateManager: StateManager, onSave: @escaping () -> Void) {
        self.existingHost = host
        self.stateManager = stateManager
        self.onSave = onSave

        if let host = host {
            _id = State(initialValue: host.id)
            _hostname = State(initialValue: host.hostname ?? "")
            _ip = State(initialValue: host.ip)
            _user = State(initialValue: host.user)
            _state = State(initialValue: host.state)
            _note = State(initialValue: host.note ?? "")
            _tagsText = State(initialValue: host.tags.joined(separator: ", "))
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(existingHost == nil ? "Add Host" : "Edit Host")
                .font(.title2)

            Form {
                TextField("ID:", text: $id)
                    .disabled(existingHost != nil)
                TextField("Hostname:", text: $hostname)
                TextField("IP Address:", text: $ip)
                TextField("User:", text: $user)
                Picker("State:", selection: $state) {
                    ForEach(SSHState.allCases, id: \.self) { s in
                        Text("\(s.icon) \(s.label)").tag(s)
                    }
                }
                TextField("Tags (comma-separated):", text: $tagsText)
                TextField("Note:", text: $note)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button(existingHost == nil ? "Add" : "Save") { save() }
                    .keyboardShortcut(.return)
                    .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }

    private var isValid: Bool {
        !id.isEmpty && !ip.isEmpty && !user.isEmpty
    }

    private func save() {
        let tags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        let host = Host(
            id: id.trimmingCharacters(in: .whitespaces),
            hostname: hostname.isEmpty ? nil : hostname,
            ip: ip.trimmingCharacters(in: .whitespaces),
            user: user.trimmingCharacters(in: .whitespaces),
            state: state,
            note: note.isEmpty ? nil : note,
            lastUsed: existingHost?.lastUsed,
            tags: tags
        )

        Task {
            await stateManager.upsertHost(host)
            onSave()
            dismiss()
        }
    }
}
