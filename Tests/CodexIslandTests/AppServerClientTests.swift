import Foundation
import XCTest
@testable import CodexIsland

final class AppServerClientTests: XCTestCase {
    func testJSONLineBufferPreservesPartialLines() throws {
        var buffer = JSONLineBuffer()

        XCTAssertTrue(buffer.append(Data(#"{"id":1"#.utf8)).isEmpty)

        let lines = buffer.append(Data("}\n{\"id\":2}\n".utf8))
        XCTAssertEqual(lines.count, 2)
        guard lines.count == 2 else { return }
        XCTAssertEqual(String(decoding: lines[0], as: UTF8.self), #"{"id":1}"#)
        XCTAssertEqual(String(decoding: lines[1], as: UTF8.self), #"{"id":2}"#)
    }

    func testInitializationTimesOutWhenServerDoesNotRespond() throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-island-timeout-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        while IFS= read -r line; do
          :
        done
        """
        try Data(script.utf8).write(to: scriptURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let client = AppServerClient(requestTimeout: 0.05)
        defer { client.stop() }
        let completion = expectation(description: "initialize timeout")

        client.start(executableURL: scriptURL, onDisconnect: { _ in }) { result in
            guard case let .failure(error) = result,
                  case let AppServerError.timedOut(method) = error else {
                return XCTFail("Expected initialize timeout, got \(result)")
            }
            XCTAssertEqual(method, "initialize")
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
    }

    func testInstallationIdentityIncludesProcessIdentifier() {
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app")
        let serverURL = appURL.appendingPathComponent("Contents/Resources/codex")
        let first = CodexInstallation(appURL: appURL, serverURL: serverURL, processIdentifier: 100)
        let restarted = CodexInstallation(appURL: appURL, serverURL: serverURL, processIdentifier: 101)

        XCTAssertNotEqual(first, restarted)
    }
}
