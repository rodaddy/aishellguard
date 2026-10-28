//
//  MenuBarPopover.swift
//  SSHGuard
//
//  Created by Claude on 2026-02-01.
//

import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @ObservedObject var stateManager: StateManager
    @State private var collapsedGroups: Set<String> = []
    @State private var searchText: String = ""
    let onManageHosts: () -> Void
    let onAddHost: () -> Void
    let onPreferences: () -> Void
    let onQuit: () -> Void

    private var pendingCount: Int {
        stateManager.state.pending.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 0) {
                HStack {
                    Text("SSHGuard")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    TextField("Search hosts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Pending section (hide when searching)
                    if pendingCount > 0 && searchText.isEmpty {
                        PendingSectionView(
                            stateManager: stateManager,
                            count: pendingCount
                        )
                        Divider()
                    }

                    // Grouped hosts
                    GroupedHostsView(
                        stateManager: stateManager,
                        collapsedGroups: $collapsedGroups,
                        searchText: searchText
                    )
                }
            }
            .frame(maxHeight: 400)

            Divider()

            // Action buttons
            VStack(spacing: 0) {
                ActionButton(title: "Manage Hosts...", action: onManageHosts)
                ActionButton(title: "Add Host...", action: onAddHost)

                Divider()
                    .padding(.horizontal, 8)

                ActionButton(title: "Preferences...", action: onPreferences)

                Divider()
                    .padding(.horizontal, 8)

                ActionButton(title: "Quit SSHGuard", action: onQuit)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 320)
    }
}

// MARK: - Pending Section

struct PendingSectionView: View {
    @ObservedObject var stateManager: StateManager
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("Pending Connections (\(count))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(stateManager.state.pending, id: \.ip) { pending in
                PendingHostRow(stateManager: stateManager, pending: pending)
            }
        }
    }
}

struct PendingHostRow: View {
    @ObservedObject var stateManager: StateManager
    let pending: PendingHost
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text("⚠️")
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(pending.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("🟢 Allow") {
                Task {
                    await stateManager.authorizePendingHost(ip: pending.ip, state: .allowed)
                }
            }
            Button("⚪ Ask") {
                Task {
                    await stateManager.authorizePendingHost(ip: pending.ip, state: .ask)
                }
            }
            Button("🔴 Block") {
                Task {
                    await stateManager.authorizePendingHost(ip: pending.ip, state: .blocked)
                }
            }
            Divider()
            Button("Dismiss") {
                Task {
                    await stateManager.removePendingHost(ip: pending.ip)
                }
            }
        }
    }
}

// MARK: - Grouped Hosts

struct GroupedHostsView: View {
    @ObservedObject var stateManager: StateManager
    @Binding var collapsedGroups: Set<String>
    var searchText: String = ""

    /// Filter hosts by search text (fuzzy matching on hostname, IP, tags)
    private var filteredHosts: [Host] {
        guard !searchText.isEmpty else { return stateManager.state.hosts }

        let query = searchText.lowercased()
        return stateManager.state.hosts.filter { host in
            // Match hostname
            if let hostname = host.hostname, fuzzyMatch(hostname.lowercased(), query) {
                return true
            }
            // Match IP
            if fuzzyMatch(host.ip, query) {
                return true
            }
            // Match any tag
            if host.tags.contains(where: { fuzzyMatch($0.lowercased(), query) }) {
                return true
            }
            // Match note
            if let note = host.note, fuzzyMatch(note.lowercased(), query) {
                return true
            }
            return false
        }
    }

    /// Simple fuzzy match: checks if all characters in query appear in target in order
    private func fuzzyMatch(_ target: String, _ query: String) -> Bool {
        var targetIndex = target.startIndex
        for queryChar in query {
            guard let foundIndex = target[targetIndex...].firstIndex(of: queryChar) else {
                return false
            }
            targetIndex = target.index(after: foundIndex)
        }
        return true
    }

    private var sortedGroups: [String] {
        // When searching, only show groups that have matching hosts
        let hostsToShow = filteredHosts
        let activeGroups = Set(hostsToShow.map { $0.tags.first ?? "ungrouped" })

        return stateManager.state.sortedGroups().filter { activeGroups.contains($0) }
    }

    private func hostsInGroup(_ group: String) -> [Host] {
        filteredHosts.filter { host in
            (host.tags.first ?? "ungrouped") == group
        }.sorted { h1, h2 in
            // Sort by hostname, then IP
            let name1 = h1.hostname ?? h1.ip
            let name2 = h2.hostname ?? h2.ip
            return name1.lowercased() < name2.lowercased()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if filteredHosts.isEmpty && !searchText.isEmpty {
                // No results message
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No hosts match \"\(searchText)\"")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(sortedGroups, id: \.self) { group in
                    let hosts = hostsInGroup(group)

                    VStack(spacing: 0) {
                        GroupHeaderRow(
                            group: group,
                            hostCount: hosts.count,
                            isCollapsed: collapsedGroups.contains(group),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if collapsedGroups.contains(group) {
                                        collapsedGroups.remove(group)
                                    } else {
                                        collapsedGroups.insert(group)
                                    }
                                }
                            },
                            onSetAll: { state in
                                setAllInGroup(group, to: state)
                            }
                        )

                        if !collapsedGroups.contains(group) {
                            ForEach(hosts, id: \.id) { host in
                                HostRow(stateManager: stateManager, host: host)
                            }
                        }
                    }
                }
            }
        }
    }

    private func setAllInGroup(_ group: String, to state: SSHState) {
        let hosts = hostsInGroup(group)
        Task {
            for host in hosts {
                await stateManager.updateHostState(id: host.id, newState: state)
            }
        }
    }
}

struct GroupHeaderRow: View {
    let group: String
    let hostCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onSetAll: (SSHState) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(isCollapsed ? "▶" : "▼")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 12)

            Text(group.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            Text("(\(hostCount))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor.withAlphaComponent(0.2)) : Color(NSColor.controlBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Text("Set All To:")
                .font(.caption)
            Divider()
            Button("🟢 Allowed") {
                onSetAll(.allowed)
            }
            Button("⚪ Ask") {
                onSetAll(.ask)
            }
            Button("🔴 Blocked") {
                onSetAll(.blocked)
            }
        }
    }
}

struct HostRow: View {
    @ObservedObject var stateManager: StateManager
    let host: Host
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(host.state.icon)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(host.hostname ?? host.ip)
                    .font(.system(size: 12))
                    .lineLimit(1)

                if host.hostname != nil {
                    Text(host.ip)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await stateManager.cycleHostState(id: host.id)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .help(host.note ?? "Click to cycle state: \(host.state.label) → \(host.state.next.label)")
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isHovered ? Color(NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Preview requires a mock StateManager instance
    // For actual preview, use: StateManager(stateFilePath: URL(fileURLWithPath: "/tmp/preview-state.json"))
    Text("MenuBarPopoverView Preview")
        .frame(width: 320, height: 400)
}
