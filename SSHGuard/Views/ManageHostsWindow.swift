import SwiftUI
import AppKit

/// Window controller for full host management
class ManageHostsWindowController: NSWindowController, NSWindowDelegate {
    static var shared: ManageHostsWindowController?

    convenience init(stateManager: StateManager, onUpdate: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: ManageHostsView(stateManager: stateManager, onUpdate: onUpdate)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "AIShell Guard - Manage Hosts"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 500))
        window.minSize = NSSize(width: 500, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating  // Keep above other windows initially

        self.init(window: window)
        window.delegate = self
    }

    static func showOrBring(stateManager: StateManager, onUpdate: @escaping () -> Void) {
        if let existing = shared, existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
        } else {
            shared = ManageHostsWindowController(stateManager: stateManager, onUpdate: onUpdate)
            shared?.showWindow(nil)
        }

        // Use activation helper for proper keyboard focus
        WindowActivation.activate(window: shared?.window)

        // Drop floating level after activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            shared?.window?.level = .normal
        }
    }

    func windowWillClose(_ notification: Notification) {
        WindowActivation.windowClosed()
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
    @State private var collapsedGroups: Set<String> = []

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

                // Host list grouped with drag & drop
                List(selection: $selectedHostID) {
                    ForEach(Array(groupedHosts.enumerated()), id: \.element.key) { index, groupData in
                        Section(header: GroupHeaderView(
                            group: groupData.key,
                            groupIndex: index,
                            isCollapsed: Binding(
                                get: { collapsedGroups.contains(groupData.key) },
                                set: { newValue in
                                    if newValue {
                                        collapsedGroups.insert(groupData.key)
                                    } else {
                                        collapsedGroups.remove(groupData.key)
                                    }
                                }
                            ),
                            stateManager: stateManager,
                            onUpdate: onUpdate
                        )) {
                            if !collapsedGroups.contains(groupData.key) {
                                ForEach(groupData.value) { host in
                                    HostRowView(host: host, stateManager: stateManager, onUpdate: onUpdate)
                                        .tag(host.id)
                                        .draggable(host.id) // Make hosts draggable by ID
                                }
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

        // Use custom order from state
        let sortedGroups = stateManager.state.sortedGroups()
        var result: [(key: String, value: [Host])] = []

        for group in sortedGroups {
            if let hosts = grouped[group] {
                result.append((key: group, value: hosts))
            }
        }

        // Add ungrouped at end if exists
        if let ungrouped = grouped["ungrouped"], !sortedGroups.contains("ungrouped") {
            result.append((key: "ungrouped", value: ungrouped))
        }

        return result
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

/// Group header that accepts dropped hosts and can be reordered
struct GroupHeaderView: View {
    let group: String
    let groupIndex: Int
    @Binding var isCollapsed: Bool
    @ObservedObject var stateManager: StateManager
    let onUpdate: () -> Void

    @State private var isHostDropTarget = false
    @State private var isGroupDropTarget = false

    var hostCount: Int {
        stateManager.state.hosts.filter { host in
            host.tags.first == group || (group == "ungrouped" && host.tags.isEmpty)
        }.count
    }

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.caption2)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            }) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand group" : "Collapse group")

            Text(group.uppercased())
                .font(.caption)
                .fontWeight(.semibold)

            Text("(\(hostCount))")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .foregroundColor(isHostDropTarget || isGroupDropTarget ? .accentColor : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            isHostDropTarget ? Color.accentColor.opacity(0.2) :
            isGroupDropTarget ? Color.orange.opacity(0.2) : Color.clear
        )
        .cornerRadius(4)
        .draggable("group:\(group)") // Draggable as group
        .dropDestination(for: String.self) { items, _ in
            for item in items {
                if item.hasPrefix("group:") {
                    // Reorder groups
                    let draggedGroup = String(item.dropFirst(6))
                    reorderGroup(draggedGroup, toIndex: groupIndex)
                } else {
                    // Move host to this group
                    moveHost(id: item, toGroup: group)
                }
            }
            return true
        } isTargeted: { targeted in
            isHostDropTarget = targeted
        }
        .contextMenu {
            Text("Set all in \(group) to:").font(.caption)
            Divider()
            Button("✅ Allow All") { setAllHostsState(.allowed) }
            Button("❓ Ask All") { setAllHostsState(.ask) }
            Button("🚫 Block All") { setAllHostsState(.blocked) }
        }
    }

    private func moveHost(id: String, toGroup: String) {
        guard let host = stateManager.state.findHost(byID: id) else { return }

        var newTags: [String] = []
        if toGroup != "ungrouped" {
            newTags.append(toGroup)
        }
        let otherTags = host.tags.dropFirst()
        newTags.append(contentsOf: otherTags)

        let updatedHost = Host(
            id: host.id,
            hostname: host.hostname,
            ip: host.ip,
            user: host.user,
            state: host.state,
            note: host.note,
            lastUsed: host.lastUsed,
            tags: newTags
        )

        Task {
            await stateManager.upsertHost(updatedHost)
            onUpdate()
        }
    }

    private func reorderGroup(_ from: String, toIndex: Int) {
        Task {
            await stateManager.moveGroup(from: from, toIndex: toIndex)
            onUpdate()
        }
    }

    private func setAllHostsState(_ newState: SSHState) {
        let hostsInGroup = stateManager.state.hosts.filter { host in
            host.tags.first == group || (group == "ungrouped" && host.tags.isEmpty)
        }

        Task {
            for host in hostsInGroup {
                let updatedHost = Host(
                    id: host.id,
                    hostname: host.hostname,
                    ip: host.ip,
                    user: host.user,
                    state: newState,
                    note: host.note,
                    lastUsed: host.lastUsed,
                    tags: host.tags
                )
                await stateManager.upsertHost(updatedHost)
            }
            onUpdate()
        }
    }
}

/// Row in host list with context menu for group changes
struct HostRowView: View {
    let host: Host
    @ObservedObject var stateManager: StateManager
    let onUpdate: () -> Void

    /// All existing groups
    private var existingGroups: [String] {
        let groups = Set(stateManager.state.hosts.compactMap { $0.tags.first })
        return groups.sorted()
    }

    /// Current group of this host
    private var currentGroup: String {
        host.tags.first ?? ""
    }

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
        .contextMenu {
            // Move to group submenu
            Menu("Move to Group") {
                Button("None (Ungrouped)") {
                    moveToGroup("")
                }
                .disabled(currentGroup.isEmpty)

                Divider()

                ForEach(existingGroups, id: \.self) { group in
                    Button(group) {
                        moveToGroup(group)
                    }
                    .disabled(group == currentGroup)
                }
            }

            Divider()

            // Quick state changes
            Menu("Set State") {
                ForEach(SSHState.allCases, id: \.self) { state in
                    Button("\(state.icon) \(state.label)") {
                        Task {
                            await stateManager.updateHostState(id: host.id, newState: state)
                            onUpdate()
                        }
                    }
                    .disabled(host.state == state)
                }
            }
        }
    }

    private func moveToGroup(_ newGroup: String) {
        Task {
            // Build new tags: new group first, then existing non-group tags
            var newTags: [String] = []
            if !newGroup.isEmpty {
                newTags.append(newGroup)
            }
            // Keep other tags (skip the first one which was the old group)
            let otherTags = host.tags.dropFirst()
            newTags.append(contentsOf: otherTags)

            let updatedHost = Host(
                id: host.id,
                hostname: host.hostname,
                ip: host.ip,
                user: host.user,
                state: host.state,
                note: host.note,
                lastUsed: host.lastUsed,
                tags: newTags
            )
            await stateManager.upsertHost(updatedHost)
            onUpdate()
        }
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

/// Sheet for adding/editing host with group selection
struct HostEditorSheet: View {
    let existingHost: Host?
    @ObservedObject var stateManager: StateManager
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var id: String = ""
    @State private var hostname: String = ""
    @State private var ip: String = ""
    @State private var user: String = NSUserName()
    @State private var state: SSHState = .ask
    @State private var note: String = ""
    @State private var selectedGroup: String = ""
    @State private var additionalTags: String = ""

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
            // First tag is the group
            _selectedGroup = State(initialValue: host.tags.first ?? "")
            // Rest are additional tags
            _additionalTags = State(initialValue: host.tags.dropFirst().joined(separator: ", "))
        }
    }

    /// Get all existing groups from current hosts
    private var existingGroups: [String] {
        let groups = Set(stateManager.state.hosts.compactMap { $0.tags.first })
        return groups.sorted()
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(existingHost == nil ? "Add Host" : "Edit Host")
                .font(.title2)

            Form {
                Section("Connection") {
                    TextField("ID:", text: $id)
                        .disabled(existingHost != nil)
                        .help("Unique identifier like 'proxmox02'")
                    TextField("Hostname:", text: $hostname)
                        .help("Display name in menu")
                    TextField("IP Address:", text: $ip)
                    TextField("User:", text: $user)
                }

                Section("Authorization") {
                    Picker("State:", selection: $state) {
                        ForEach(SSHState.allCases, id: \.self) { s in
                            Text("\(s.icon) \(s.label)").tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Organization") {
                    // Combo box style: type or pick from menu
                    HStack {
                        Text("Group:")
                        TextField("Type or select...", text: $selectedGroup)
                            .textFieldStyle(.roundedBorder)

                        Menu {
                            Button("None (ungrouped)") {
                                selectedGroup = ""
                            }
                            Divider()
                            ForEach(existingGroups, id: \.self) { group in
                                Button(group) {
                                    selectedGroup = group
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 24)
                    }
                    .help("Type a new group name or pick from existing")

                    TextField("Additional Tags:", text: $additionalTags)
                        .help("Comma-separated extra tags (optional)")
                }

                Section("Info") {
                    TextField("Note:", text: $note)
                }
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
        .frame(width: 450, height: 480)
    }

    private var isValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty &&
        !ip.trimmingCharacters(in: .whitespaces).isEmpty &&
        !user.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        // Build tags array: group first, then additional tags
        var tags: [String] = []
        if !selectedGroup.isEmpty {
            tags.append(selectedGroup.lowercased())
        }
        let extraTags = additionalTags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty && $0 != selectedGroup.lowercased() }
        tags.append(contentsOf: extraTags)

        let host = Host(
            id: id.trimmingCharacters(in: .whitespaces),
            hostname: hostname.isEmpty ? nil : hostname.trimmingCharacters(in: .whitespaces),
            ip: ip.trimmingCharacters(in: .whitespaces),
            user: user.trimmingCharacters(in: .whitespaces),
            state: state,
            note: note.isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
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
