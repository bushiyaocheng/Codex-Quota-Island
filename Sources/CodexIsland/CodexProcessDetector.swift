import AppKit
import Foundation

struct CodexInstallation: Equatable, Sendable {
    let appURL: URL
    let serverURL: URL
    let processIdentifier: pid_t
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

        guard let serverURL = Self.appServerExecutable(in: appURL) else { return nil }
        return CodexInstallation(
            appURL: appURL,
            serverURL: serverURL,
            processIdentifier: application.processIdentifier
        )
    }

    nonisolated static func appServerExecutable(in appURL: URL) -> URL? {
        let resourceURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        let relativePaths = [
            "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "codex"
        ]

        return relativePaths
            .map { resourceURL.appendingPathComponent($0, isDirectory: false) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
