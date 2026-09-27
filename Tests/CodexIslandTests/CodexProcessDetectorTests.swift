import Foundation
import XCTest
@testable import CodexIsland

final class CodexProcessDetectorTests: XCTestCase {
    func testFindsCurrentCodexCLIInsideAppBundle() throws {
        let appURL = try temporaryApp()
        defer { try? FileManager.default.removeItem(at: appURL) }

        let executable = appURL.appendingPathComponent(
            "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        )
        try createExecutable(at: executable)

        XCTAssertEqual(CodexProcessDetector.appServerExecutable(in: appURL), executable)
    }

    func testFallsBackToLegacyCodexExecutable() throws {
        let appURL = try temporaryApp()
        defer { try? FileManager.default.removeItem(at: appURL) }

        let executable = appURL.appendingPathComponent("Contents/Resources/codex")
        try createExecutable(at: executable)

        XCTAssertEqual(CodexProcessDetector.appServerExecutable(in: appURL), executable)
    }

    private func temporaryApp() throws -> URL {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexIslandDetector-\(UUID().uuidString).app")
        try FileManager.default.createDirectory(
            at: appURL,
            withIntermediateDirectories: true
        )
        return appURL
    }

    private func createExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }
}
