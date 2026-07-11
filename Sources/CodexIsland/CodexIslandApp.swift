import AppKit
import SwiftUI

@main
struct CodexIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var usageController: UsageController?
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let usage = UsageController()
        usageController = usage
        panelController = NotchPanelController(usage: usage)
        usage.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageController?.stop()
    }
}
