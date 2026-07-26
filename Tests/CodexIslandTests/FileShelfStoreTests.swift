import AppKit
import Foundation
import XCTest
@testable import CodexIsland

final class FileShelfStoreTests: XCTestCase {
    @MainActor
    func testAddsAndDeduplicatesFilesOnlyWithinSession() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let firstFile = context.root.appendingPathComponent("first.png")
        let secondFile = context.root.appendingPathComponent("notes.md")
        try Data("image".utf8).write(to: firstFile)
        try Data("notes".utf8).write(to: secondFile)

        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertEqual(store.addFiles([firstFile, firstFile, secondFile]), 2)
        XCTAssertEqual(store.items.map(\.displayName), ["first.png", "notes.md"])

        let nextSession = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertTrue(nextSession.items.isEmpty)
    }

    @MainActor
    func testRejectsDirectoriesAndMissingFiles() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertEqual(
            store.addFiles([
                context.root,
                context.root.appendingPathComponent("missing.txt")
            ]),
            0
        )
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testRemovingOriginalOnlyRemovesShelfRecord() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let original = context.root.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: original)
        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertEqual(store.addFiles([original]), 1)

        store.remove(try XCTUnwrap(store.items.first))

        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testRemovingManagedCopyDeletesOnlyManagedFile() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        try FileManager.default.createDirectory(
            at: context.managedDirectory,
            withIntermediateDirectories: true
        )
        let managedFile = context.managedDirectory.appendingPathComponent("drop.png")
        try Data("managed".utf8).write(to: managedFile)
        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertEqual(store.addManagedFile(managedFile), 1)

        store.remove(try XCTUnwrap(store.items.first))

        XCTAssertFalse(FileManager.default.fileExists(atPath: managedFile.path))
    }

    @MainActor
    func testSuccessfulOutboundDragRemovesItemButCancelledDragKeepsIt() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let original = context.root.appendingPathComponent("send.txt")
        try Data("send".utf8).write(to: original)
        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertEqual(store.addFiles([original]), 1)
        let item = try XCTUnwrap(store.items.first)

        store.completeOutboundDrag(of: item, accepted: false)
        XCTAssertEqual(store.items.count, 1)

        store.completeOutboundDrag(of: item, accepted: true)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    @MainActor
    func testShutdownClearsRecordsAndManagedTemporaryCopies() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let original = context.root.appendingPathComponent("original.txt")
        try Data("original".utf8).write(to: original)
        try FileManager.default.createDirectory(
            at: context.managedDirectory,
            withIntermediateDirectories: true
        )
        let managedFile = context.managedDirectory.appendingPathComponent("drop.png")
        try Data("managed".utf8).write(to: managedFile)

        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        XCTAssertEqual(store.addFiles([original]), 1)
        XCTAssertEqual(store.addManagedFile(managedFile), 1)

        store.shutdown()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: context.managedDirectory.path))
    }

    @MainActor
    func testImportsFileURLFromNativeItemProvider() async throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let file = context.root.appendingPathComponent("drop.png")
        try Data("drop".utf8).write(to: file)
        let store = FileShelfStore(
            defaults: context.defaults,
            managedDirectory: context.managedDirectory
        )
        let provider = try XCTUnwrap(NSItemProvider(contentsOf: file))

        XCTAssertTrue(store.importProviders([provider]))
        for _ in 0..<20 where store.items.isEmpty {
            try await Task.sleep(for: .milliseconds(25))
        }

        XCTAssertEqual(store.items.first?.url, file.standardizedFileURL)
    }

    func testOutboundPayloadPublishesNativeFileURL() throws {
        let file = URL(fileURLWithPath: "/tmp/codex-island-drag-test.png")
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("CodexIslandTests.\(UUID().uuidString)")
        )
        pasteboard.clearContents()

        XCTAssertTrue(
            pasteboard.writeObjects([FileDragPayload.pasteboardWriter(for: file)])
        )
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL]

        XCTAssertEqual(urls?.first as URL?, file)
        XCTAssertFalse(FileDragPayload.wasAccepted([]))
        XCTAssertTrue(FileDragPayload.wasAccepted(.copy))
    }

    private func makeContext() throws -> TestContext {
        let suiteName = "FileShelfStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexIslandTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return TestContext(
            suiteName: suiteName,
            defaults: defaults,
            root: root,
            managedDirectory: root.appendingPathComponent("Managed", isDirectory: true)
        )
    }
}

private struct TestContext {
    let suiteName: String
    let defaults: UserDefaults
    let root: URL
    let managedDirectory: URL

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
}
