import AppKit
import Foundation

struct CodexInstallation: Equatable, Sendable {
    let appURL: URL
    let serverURL: URL
}

@MainActor
final class CodexProcessDetector {
    func runningInstallation() -> CodexInstallation? {
        let candidates = NSWorkspace.shared.runningApplications.compactMap(installation(for:))
        return candidates.first
    }

    private func installation(for application: NSRunningApplication) -> CodexInstallation? {
        guard let appURL = application.bundleURL else { return nil }

        let appName = appURL.deletingPathExtension().lastPathComponent.lowercased()
        let bundleID = application.bundleIdentifier?.lowercased() ?? ""
        let looksLikeCodex = appName == "codex"
            || appName == "chatgpt"
            || bundleID.contains("openai.codex")

        guard looksLikeCodex else { return nil }

        let serverURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("codex", isDirectory: false)

        guard FileManager.default.isExecutableFile(atPath: serverURL.path) else { return nil }
        return CodexInstallation(appURL: appURL, serverURL: serverURL)
    }
}
