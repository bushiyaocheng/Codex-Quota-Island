import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else {
            errorMessage = "请先运行打包后的 Codex Island.app"
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    private func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
