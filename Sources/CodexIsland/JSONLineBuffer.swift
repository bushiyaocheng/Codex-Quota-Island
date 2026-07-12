import Foundation

struct JSONLineBuffer {
    private var storage = Data()

    mutating func append(_ data: Data) -> [Data] {
        storage.append(data)
        var lines: [Data] = []
        while let newline = storage.firstIndex(of: 0x0A) {
            lines.append(Data(storage[..<newline]))
            storage.removeSubrange(...newline)
        }
        return lines
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: false)
    }
}
