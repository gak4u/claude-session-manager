import SwiftUI

struct DashboardView: View {
    let store: SessionStore
    let discovery: ActiveDiscovery

    @State private var newName: String = ""
    @State private var newPath: String = ""
    @State private var alert: AlertItem?
    @State private var renameTarget: Session?
    @State private var saveAsTarget: ActiveSession?

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                saveForm
                if !unsavedActive.isEmpty {
                    section(title: "Active now",
                            hint: "unsaved sessions touched in the last 8h") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(unsavedActive) { s in
                                ActiveCardView(session: s) {
                                    saveAsTarget = s
                                }
                            }
                        }
                    }
                }
                section(title: "Saved") {
                    if store.sessions.isEmpty {
                        emptyView
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(store.sessions) { s in
                                SessionCardView(
                                    session: s,
                                    onResume: { resume(s) },
                                    onRename: { renameTarget = s },
                                    onDelete: { delete(s) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(item: $alert) { item in
            Alert(title: Text(item.title), message: Text(item.message))
        }
        .sheet(item: $renameTarget) { target in
            RenameSheet(currentName: target.name) { newName in
                rename(target, to: newName)
            }
        }
        .sheet(item: $saveAsTarget) { target in
            SaveAsSheet(suggested: target.projectName, projectPath: target.displayPath) { name in
                saveActive(target, as: name)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("CSM")
                .font(.system(size: 22, weight: .semibold))
            Text("Claude session manager")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var saveForm: some View {
        HStack(spacing: 8) {
            TextField("session name (e.g. xpat-api)", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160, maxWidth: 220)
            PathPickerField(path: $newPath) { picked in
                if newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    newName = (picked as NSString).lastPathComponent
                }
            }
            Button("Save") { saveCurrent() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty
                          || newPath.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    private var emptyView: some View {
        Text("No saved sessions yet. Use the form above, or save one of the active sessions.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
    }

    private var unsavedActive: [ActiveSession] {
        let savedIDs = Set(store.sessions.map(\.sessionID))
        return discovery.active.filter { !savedIDs.contains($0.sessionID) }
    }

    // MARK: actions

    private func saveCurrent() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let path = newPath.trimmingCharacters(in: .whitespaces)
        do {
            try store.saveSession(name: name, projectPath: path)
            newName = ""
            newPath = ""
        } catch {
            alert = AlertItem(title: "Save failed", message: error.localizedDescription)
        }
    }

    private func saveActive(_ s: ActiveSession, as name: String) {
        do {
            try store.saveSession(name: name, projectPath: s.projectPath, force: false)
        } catch {
            alert = AlertItem(title: "Save failed", message: error.localizedDescription)
        }
    }

    private func resume(_ s: Session) {
        do {
            try ITermLauncher.resume(name: s.name, projectPath: s.projectPath, sessionID: s.sessionID)
        } catch {
            alert = AlertItem(title: "Resume failed", message: error.localizedDescription)
        }
    }

    private func delete(_ s: Session) {
        do {
            try store.delete(name: s.name)
        } catch {
            alert = AlertItem(title: "Delete failed", message: error.localizedDescription)
        }
    }

    private func rename(_ s: Session, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != s.name else { return }
        do {
            try store.rename(s.name, to: trimmed)
        } catch {
            alert = AlertItem(title: "Rename failed", message: error.localizedDescription)
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct PathPickerField: View {
    @Binding var path: String
    var onPick: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(path.isEmpty ? "Choose a project folder…" : displayedPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { browse() }
            Button("Browse…") { browse() }
                .buttonStyle(.bordered)
        }
    }

    private var displayedPath: String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose project folder"
        panel.message = "Pick the folder where you've been running Claude."
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            let resolved = url.standardizedFileURL.path
            path = resolved
            onPick(resolved)
        }
    }
}

struct RenameSheet: View {
    let currentName: String
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String

    init(currentName: String, onSubmit: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onSubmit = onSubmit
        _newName = State(initialValue: currentName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename session")
                .font(.headline)
            Text("Current: \(currentName)")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("new name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") { submit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func submit() {
        onSubmit(newName)
        dismiss()
    }
}

struct SaveAsSheet: View {
    let suggested: String
    let projectPath: String
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(suggested: String, projectPath: String, onSubmit: @escaping (String) -> Void) {
        self.suggested = suggested
        self.projectPath = projectPath
        self.onSubmit = onSubmit
        _name = State(initialValue: suggested)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save active session")
                .font(.headline)
            Text(projectPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            TextField("name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { submit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func submit() {
        onSubmit(name)
        dismiss()
    }
}
