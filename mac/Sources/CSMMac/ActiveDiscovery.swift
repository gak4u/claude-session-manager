import Foundation
import Observation

@MainActor
@Observable
final class ActiveDiscovery {
    private(set) var active: [ActiveSession] = []
    var windowSeconds: TimeInterval = 8 * 3600

    private var pollTimer: Timer?
    private let claudeProjects: URL

    init() {
        self.claudeProjects = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        refresh()
    }

    func startPolling(interval: TimeInterval = 5) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refresh() {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: claudeProjects,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            active = []
            return
        }

        var found: [ActiveSession] = []
        for dir in projectDirs {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                guard
                    let mtime = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate,
                    mtime >= cutoff
                else { continue }
                guard let cwd = readCWD(from: file) else { continue }
                found.append(
                    ActiveSession(
                        sessionID: file.deletingPathExtension().lastPathComponent,
                        projectPath: cwd,
                        lastActive: mtime
                    )
                )
            }
        }
        found.sort { $0.lastActive > $1.lastActive }
        if found != active {
            active = found
        }
    }

    private func readCWD(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // First ~16KB is plenty for the early metadata records that contain `cwd`.
        guard let data = try? handle.read(upToCount: 16 * 1024) else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            guard
                let lineData = line.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                let cwd = obj["cwd"] as? String
            else { continue }
            return cwd
        }
        return nil
    }
}
