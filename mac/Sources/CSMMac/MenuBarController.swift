import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: SessionStore
    private let discovery: ActiveDiscovery
    private let openDashboard: () -> Void
    private var rebuildTimer: Timer?

    init(
        store: SessionStore,
        discovery: ActiveDiscovery,
        openDashboard: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.discovery = discovery
        self.openDashboard = openDashboard
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.stack",
                accessibilityDescription: "CSM"
            )
            button.image?.isTemplate = true
        }
        rebuild()
        // Cheap rebuild every 5s to keep timestamps and active list fresh.
        rebuildTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
    }

    deinit {
        // Timer/StatusItem cleanup happens at app termination; nothing to do here.
    }

    func rebuild() {
        let menu = NSMenu()

        if store.sessions.isEmpty {
            let empty = NSMenuItem(title: "No saved sessions", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let header = NSMenuItem(title: "Saved sessions", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for session in store.sessions {
                let item = NSMenuItem(
                    title: session.name,
                    action: #selector(resumeSelected(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = session
                item.toolTip = "\(session.displayPath)\n\(session.shortID) · \(RelativeTime.format(session.savedAt))"
                menu.addItem(item)
            }
        }

        let savedIDs = Set(store.sessions.map(\.sessionID))
        let unsaved = discovery.active.filter { !savedIDs.contains($0.sessionID) }
        if !unsaved.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: "Active (unsaved)", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for active in unsaved {
                let item = NSMenuItem(
                    title: "\(active.projectName)  ·  \(active.shortID)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.toolTip = active.displayPath
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let dashItem = NSMenuItem(
            title: "Open Dashboard…",
            action: #selector(openDashboardClicked),
            keyEquivalent: "d"
        )
        dashItem.target = self
        menu.addItem(dashItem)

        let quitItem = NSMenuItem(
            title: "Quit CSM",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func resumeSelected(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session else { return }
        do {
            try ITermLauncher.resume(
                name: session.name,
                projectPath: session.projectPath,
                sessionID: session.sessionID
            )
        } catch {
            let alert = NSAlert()
            alert.messageText = "Resume failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func openDashboardClicked() {
        openDashboard()
    }
}
