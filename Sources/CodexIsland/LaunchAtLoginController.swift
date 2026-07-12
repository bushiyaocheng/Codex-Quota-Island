import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    private(set) var isEnabled = false

    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else {
            AppLog.launchAtLogin.warning("Launch at login requires an app bundle")
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.launchAtLogin.error("Failed to update launch at login: \(error.localizedDescription, privacy: .private)")
        }
        refresh()
    }

    private func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
