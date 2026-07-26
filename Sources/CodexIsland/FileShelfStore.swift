import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class FileShelfStore: ObservableObject {
    static let acceptedTypeIdentifiers = [
        UTType.fileURL.identifier,
        UTType.image.identifier
    ]

    @Published private(set) var items: [FileShelfItem] = []
    @Published private(set) var notice = ""

    static let legacyStorageKey = "fileShelfItems.v2"

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let managedDirectory: URL

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        managedDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.managedDirectory = managedDirectory
            ?? fileManager.temporaryDirectory
                .appendingPathComponent("CodexIsland", isDirectory: true)
                .appendingPathComponent("FileShelf", isDirectory: true)

        if managedDirectory == nil {
            clearPreviousTemporaryStorage()
            removeLegacyPersistence()
        }
    }

    @discardableResult
    func addFiles(_ urls: [URL]) -> Int {
        add(urls, isManagedCopy: false)
    }

    @discardableResult
    func addManagedFile(_ url: URL) -> Int {
        add([url], isManagedCopy: true)
    }

    @discardableResult
    func chooseFiles() -> Int {
        let panel = NSOpenPanel()
        panel.title = "添加到文件暂存"
        panel.prompt = "暂存"
        panel.message = "文件只保留到本次退出前，可从灵动岛直接拖到 Codex"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return 0 }
        return addFiles(panel.urls)
    }

    func remove(_ item: FileShelfItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = items.remove(at: index)
        deleteManagedCopyIfNeeded(removed)
        notice = items.isEmpty ? "" : "已移除 \(removed.displayName)"
    }

    func clear() {
        let removedItems = items
        items.removeAll()
        removedItems.forEach(deleteManagedCopyIfNeeded)
        notice = "暂存区已清空"
    }

    func completeOutboundDrag(of item: FileShelfItem, accepted: Bool) {
        completeOutboundDrag(of: [item], accepted: accepted)
    }

    func completeOutboundDrag(of outboundItems: [FileShelfItem], accepted: Bool) {
        guard accepted else { return }
        let outboundIDs = Set(outboundItems.map(\.id))
        let removedItems = items.filter { outboundIDs.contains($0.id) }
        guard !removedItems.isEmpty else { return }

        items.removeAll { outboundIDs.contains($0.id) }
        removedItems.forEach(deleteManagedCopyIfNeeded)
        notice = items.isEmpty
            ? ""
            : "已拖出 \(removedItems.count) 个文件"
    }

    func shutdown() {
        let removedItems = items
        items.removeAll()
        removedItems.forEach(deleteManagedCopyIfNeeded)
        try? fileManager.removeItem(at: managedDirectory)
        notice = ""
    }

    func importProviders(_ providers: [NSItemProvider]) -> Bool {
        let acceptedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
        guard !acceptedProviders.isEmpty else {
            notice = "这里暂时只接收文件和图片"
            return false
        }

        for provider in acceptedProviders {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                importFileURL(from: provider)
            } else {
                importImageRepresentation(from: provider)
            }
        }
        return true
    }

    private func add(_ urls: [URL], isManagedCopy: Bool) -> Int {
        let existingPaths = Set(items.map { canonicalURL(for: $0.url).path })
        var seenPaths = existingPaths
        var additions: [FileShelfItem] = []

        for url in urls {
            let canonicalURL = canonicalURL(for: url)
            guard isRegularFile(at: canonicalURL), !seenPaths.contains(canonicalURL.path) else {
                continue
            }
            seenPaths.insert(canonicalURL.path)
            additions.append(FileShelfItem(url: canonicalURL, isManagedCopy: isManagedCopy))
        }

        guard !additions.isEmpty else {
            notice = "文件已在暂存区，或当前无法读取"
            return 0
        }

        items.append(contentsOf: additions)
        notice = additions.count == 1
            ? "已暂存 \(additions[0].displayName)"
            : "已暂存 \(additions.count) 个文件"
        return additions.count
    }

    private func clearPreviousTemporaryStorage() {
        try? fileManager.removeItem(at: managedDirectory)
    }

    private func removeLegacyPersistence() {
        let legacyDirectory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexIsland", isDirectory: true)
            .appendingPathComponent("FileShelf", isDirectory: true)
        try? fileManager.removeItem(at: legacyDirectory)
        defaults.removeObject(forKey: Self.legacyStorageKey)
    }

    private func canonicalURL(for url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func isRegularFile(at url: URL) -> Bool {
        guard url.isFileURL else { return false }
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    private func deleteManagedCopyIfNeeded(_ item: FileShelfItem) {
        guard item.isManagedCopy,
              item.url.path.hasPrefix(managedDirectory.path + "/") else { return }
        try? fileManager.removeItem(at: item.url)
    }

    private func importFileURL(from provider: NSItemProvider) {
        provider.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { [weak self] value, error in
            guard error == nil, let url = Self.decodeFileURL(from: value) else {
                Task { @MainActor in
                    self?.notice = "无法读取拖入的文件"
                }
                return
            }
            Task { @MainActor in
                _ = self?.addFiles([url])
            }
        }
    }

    private func importImageRepresentation(from provider: NSItemProvider) {
        let destinationDirectory = managedDirectory
        let imageType = provider.registeredTypeIdentifiers
            .compactMap(UTType.init)
            .first { $0.conforms(to: .image) }
        let typeIdentifier = imageType?.identifier ?? UTType.image.identifier
        let preferredExtension = imageType?.preferredFilenameExtension ?? "png"

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] sourceURL, error in
            guard error == nil, let sourceURL else {
                Task { @MainActor in
                    self?.notice = "无法读取拖入的图片"
                }
                return
            }

            do {
                let callbackFileManager = FileManager()
                try callbackFileManager.createDirectory(
                    at: destinationDirectory,
                    withIntermediateDirectories: true
                )
                let fileExtension = sourceURL.pathExtension.isEmpty
                    ? preferredExtension
                    : sourceURL.pathExtension
                let destinationURL = destinationDirectory
                    .appendingPathComponent("drop-\(UUID().uuidString)")
                    .appendingPathExtension(fileExtension)
                try callbackFileManager.copyItem(at: sourceURL, to: destinationURL)
                Task { @MainActor in
                    _ = self?.addManagedFile(destinationURL)
                }
            } catch {
                Task { @MainActor in
                    self?.notice = "暂存图片失败"
                }
            }
        }
    }

    private nonisolated static func decodeFileURL(from value: NSSecureCoding?) -> URL? {
        if let url = value as? URL {
            return url
        }
        if let url = value as? NSURL {
            return url as URL
        }
        if let data = value as? Data,
           let string = String(data: data, encoding: .utf8) {
            return decodeURLString(string)
        }
        if let string = value as? String {
            return decodeURLString(string)
        }
        return nil
    }

    private nonisolated static func decodeURLString(_ value: String) -> URL? {
        let string = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return string.hasPrefix("/")
            ? URL(fileURLWithPath: string)
            : URL(string: string)
    }
}
