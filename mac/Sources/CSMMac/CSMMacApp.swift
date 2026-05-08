import SwiftUI
import AppKit

@MainActor
enum AppState {
    static let store = SessionStore()
    static let discovery = ActiveDiscovery()
}

@main
struct CSMMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("CSM — Claude Session Manager", id: "main") {
            DashboardView(store: AppState.store, discovery: AppState.discovery)
                .onAppear {
                    AppState.store.startPolling()
                    AppState.discovery.startPolling()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .windowList) {
                Button("Refresh") {
                    AppState.store.load()
                    AppState.discovery.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(
            store: AppState.store,
            discovery: AppState.discovery,
            openDashboard: { [weak self] in self?.openMainWindow() }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay alive in the menu bar even when the dashboard is closed.
        false
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
