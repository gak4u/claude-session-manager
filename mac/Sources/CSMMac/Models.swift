import Foundation

struct Session: Identifiable, Hashable, Codable {
    var name: String
    var sessionID: String
    var projectPath: String
    var savedAt: Date

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case projectPath = "project_path"
        case savedAt = "saved_at"
        case name
    }
}

struct ActiveSession: Identifiable, Hashable {
    let sessionID: String
    let projectPath: String
    let lastActive: Date

    var id: String { sessionID }
}

struct SessionsFile: Codable {
    var sessions: [String: SessionEntry]
}

struct SessionEntry: Codable, Hashable {
    var sessionID: String
    var projectPath: String
    var savedAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case projectPath = "project_path"
        case savedAt = "saved_at"
    }
}

extension Session {
    init(name: String, entry: SessionEntry) {
        self.name = name
        self.sessionID = entry.sessionID
        self.projectPath = entry.projectPath
        self.savedAt = entry.savedAt
    }

    var entry: SessionEntry {
        SessionEntry(sessionID: sessionID, projectPath: projectPath, savedAt: savedAt)
    }

    var shortID: String {
        String(sessionID.prefix(8)) + "…"
    }

    var displayPath: String {
        let home = NSHomeDirectory()
        if projectPath.hasPrefix(home) {
            return "~" + projectPath.dropFirst(home.count)
        }
        return projectPath
    }
}

extension ActiveSession {
    var shortID: String {
        String(sessionID.prefix(8)) + "…"
    }

    var displayPath: String {
        let home = NSHomeDirectory()
        if projectPath.hasPrefix(home) {
            return "~" + projectPath.dropFirst(home.count)
        }
        return projectPath
    }

    var projectName: String {
        (projectPath as NSString).lastPathComponent
    }
}
