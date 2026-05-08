import Foundation
import AppKit

enum ITermLauncher {
    static func resume(name: String, projectPath: String, sessionID: String) throws {
        // Detection runs inside the spawned tab's shell so it picks up the
        // user's interactive PATH (which may differ from the GUI app's).
        let sid = shellQuote(sessionID)
        let resumeCmd =
            "if command -v superclaude >/dev/null 2>&1; then "
            + "superclaude --resume \(sid); "
            + "else "
            + "claude --dangerously-skip-permissions --resume \(sid); "
            + "fi"
        let shellCmd = "cd \(shellQuote(projectPath)) && \(resumeCmd)"
        let n = applescriptEscape(name)
        let c = applescriptEscape(shellCmd)
        let source = """
        tell application "iTerm2"
            activate
            if (count of windows) = 0 then
                create window with default profile
                tell current session of current window
                    set name to "\(n)"
                    write text "\(c)"
                end tell
            else
                tell current window
                    set newTab to (create tab with default profile)
                    tell current session of newTab
                        set name to "\(n)"
                        write text "\(c)"
                    end tell
                end tell
            end if
        end tell
        """
        try runAppleScript(source)
    }

    private static func runAppleScript(_ source: String) throws {
        var errorDict: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw NSError(
                domain: "CSMMac",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "could not compile AppleScript"]
            )
        }
        script.executeAndReturnError(&errorDict)
        if let err = errorDict {
            let msg = err[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
            throw NSError(
                domain: "CSMMac",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func applescriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
