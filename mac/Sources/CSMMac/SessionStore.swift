import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []
    private(set) var lastError: String?

    private let dbURL: URL
    private var pollTimer: Timer?

    init(dbURL: URL = SessionStore.defaultDBURL()) {
        self.dbURL = dbURL
        load()
    }

    static func defaultDBURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".csm/sessions.json")
    }

    func startPolling(interval: TimeInterval = 2) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func load() {
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            sessions = []
            return
        }
        do {
            let data = try Data(contentsOf: dbURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let file = try decoder.decode(SessionsFile.self, from: data)
            let loaded = file.sessions
                .map { Session(name: $0.key, entry: $0.value) }
                .sorted { $0.savedAt > $1.savedAt }
            if loaded != sessions {
                sessions = loaded
            }
            lastError = nil
        } catch {
            lastError = "load failed: \(error.localizedDescription)"
        }
    }

    func save(_ allSessions: [Session]) throws {
        let entries = Dictionary(uniqueKeysWithValues: allSessions.map { ($0.name, $0.entry) })
        let file = SessionsFile(sessions: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)

        try FileManager.default.createDirectory(
            at: dbURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let tmp = dbURL.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(dbURL, withItemAt: tmp)
        sessions = allSessions.sorted { $0.savedAt > $1.savedAt }
    }

    // MARK: mutations

    func saveSession(name: String, projectPath: String, force: Bool = false) throws {
        let path = (projectPath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw CSMError.invalidPath(url.path)
        }
        if !force, sessions.contains(where: { $0.name == name }) {
            throw CSMError.nameExists(name)
        }
        let sid = try detectCurrentSessionID(forProject: url)
        var copy = sessions.filter { $0.name != name }
        copy.append(
            Session(
                name: name,
                sessionID: sid,
                projectPath: url.path,
                savedAt: Date()
            )
        )
        try save(copy)
    }

    func delete(name: String) throws {
        try save(sessions.filter { $0.name != name })
    }

    func rename(_ old: String, to new: String) throws {
        guard !sessions.contains(where: { $0.name == new }) else {
            throw CSMError.nameExists(new)
        }
        guard let idx = sessions.firstIndex(where: { $0.name == old }) else {
            throw CSMError.notFound(old)
        }
        var copy = sessions
        copy[idx].name = new
        copy[idx].savedAt = Date()
        try save(copy)
    }
}

enum CSMError: LocalizedError {
    case invalidPath(String)
    case nameExists(String)
    case notFound(String)
    case noClaudeProject(String)
    case noSessions(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let p): return "not a directory: \(p)"
        case .nameExists(let n): return "'\(n)' already exists"
        case .notFound(let n): return "no session named '\(n)'"
        case .noClaudeProject(let p): return "no Claude project at \(p) — have you run claude here?"
        case .noSessions(let p): return "no .jsonl sessions in \(p)"
        }
    }
}

func projectDirFor(_ projectURL: URL) -> URL {
    let claudeProjects = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")
    let path = projectURL.path
    let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
    let flat = "-" + trimmed.replacingOccurrences(of: "/", with: "-")
    return claudeProjects.appendingPathComponent(flat)
}

func detectCurrentSessionID(forProject url: URL) throws -> String {
    let pdir = projectDirFor(url)
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: pdir.path, isDirectory: &isDir), isDir.boolValue else {
        throw CSMError.noClaudeProject(pdir.path)
    }
    let files = try FileManager.default.contentsOfDirectory(
        at: pdir,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    )
    .filter { $0.pathExtension == "jsonl" }
    let sorted = files.sorted { a, b in
        let am = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let bm = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return am > bm
    }
    guard let newest = sorted.first else {
        throw CSMError.noSessions(pdir.path)
    }
    return newest.deletingPathExtension().lastPathComponent
}
