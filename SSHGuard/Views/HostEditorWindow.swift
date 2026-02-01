import SwiftUI
import AppKit

/// Window controller for host editor
class HostEditorWindowController: NSWindowController, NSWindowDelegate {
    convenience init(host: Host?, stateManager: StateManager, onSave: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: HostEditorView(
                host: host,
                stateManager: stateManager,
                onSave: onSave
            )
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = host == nil ? "Add Host" : "Edit Host"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.init(window: window)
        window.delegate = self
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        // Use activation helper for proper keyboard focus
        WindowActivation.activate(window: window)

        // Drop floating level after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.window?.level = .normal
        }
    }

    func windowWillClose(_ notification: Notification) {
        WindowActivation.windowClosed()
    }
}

/// SwiftUI view for adding/editing a host
struct HostEditorView: View {
    let existingHost: Host?
    @ObservedObject var stateManager: StateManager
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var id: String = ""
    @State private var hostname: String = ""
    @State private var ip: String = ""
    @State private var user: String = "rico"
    @State private var state: SSHState = .ask
    @State private var note: String = ""
    @State private var tagsText: String = ""

    @State private var showError = false
    @State private var errorMessage = ""

    init(host: Host?, stateManager: StateManager, onSave: @escaping () -> Void) {
        self.existingHost = host
        self.stateManager = stateManager
        self.onSave = onSave

        // Pre-fill form if editing
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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(existingHost == nil ? "Add New Host" : "Edit Host")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // Form
            Form {
                Section {
                    TextField("ID (unique identifier):", text: $id)
                        .disabled(existingHost != nil)
                        .help("Unique ID like 'proxmox02' or 'lxc-202-n8n'")

                    TextField("Hostname (display name):", text: $hostname)
                        .help("Friendly name shown in menu")

                    TextField("IP Address:", text: $ip)
                        .help("IP address or hostname for SSH connection")

                    TextField("SSH User:", text: $user)
                        .help("Username for SSH connection")
                }

                Section {
                    Picker("State:", selection: $state) {
                        ForEach(SSHState.allCases, id: \.self) { state in
                            Text("\(state.icon) \(state.label)").tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Tags (comma-separated):", text: $tagsText)
                        .help("e.g., 'lxc, production, database' - first tag determines group")

                    TextField("Note:", text: $note)
                        .help("Description or reminder about this host")
                }
            }
            .formStyle(.grouped)

            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Divider()

            // Buttons
            HStack {
                if existingHost != nil {
                    Button("Delete", role: .destructive) {
                        Task {
                            await stateManager.removeHost(id: existingHost!.id)
                            onSave()
                            NSApp.keyWindow?.close()
                        }
                    }
                }

                Spacer()

                Button("Cancel") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.escape)

                Button(existingHost == nil ? "Add Host" : "Save") {
                    saveHost()
                }
                .keyboardShortcut(.return)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 450, height: 420)
    }

    private var isValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty &&
        !ip.trimmingCharacters(in: .whitespaces).isEmpty &&
        !user.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveHost() {
        guard isValid else {
            errorMessage = "ID, IP, and User are required"
            showError = true
            return
        }

        // Parse tags
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

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
            NSApp.keyWindow?.close()
        }
    }
}
