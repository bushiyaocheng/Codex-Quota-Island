import Foundation
import UniformTypeIdentifiers

struct FileShelfItem: Codable, Hashable, Identifiable {
    let id: UUID
    let url: URL
    let isManagedCopy: Bool

    init(id: UUID = UUID(), url: URL, isManagedCopy: Bool = false) {
        self.id = id
        self.url = url
        self.isManagedCopy = isManagedCopy
    }

    var displayName: String {
        url.lastPathComponent
    }

    var isImage: Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
