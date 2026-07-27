import AppKit
import SwiftUI

enum FileDragPayload {
    static func pasteboardWriter(for fileURL: URL) -> NSURL {
        fileURL as NSURL
    }

    static func wasAccepted(_ operation: NSDragOperation) -> Bool {
        !operation.isEmpty
    }
}

struct FileDragSource: NSViewRepresentable {
    let fileURLs: [URL]
    let onDragBegan: () -> Void
    let onDragEnded: (Bool) -> Void

    init(
        fileURL: URL,
        onDragBegan: @escaping () -> Void,
        onDragEnded: @escaping (Bool) -> Void
    ) {
        self.init(
            fileURLs: [fileURL],
            onDragBegan: onDragBegan,
            onDragEnded: onDragEnded
        )
    }

    init(
        fileURLs: [URL],
        onDragBegan: @escaping () -> Void,
        onDragEnded: @escaping (Bool) -> Void
    ) {
        self.fileURLs = fileURLs
        self.onDragBegan = onDragBegan
        self.onDragEnded = onDragEnded
    }

    func makeNSView(context: Context) -> FileDragSourceView {
        FileDragSourceView(
            fileURLs: fileURLs,
            onDragBegan: onDragBegan,
            onDragEnded: onDragEnded
        )
    }

    func updateNSView(_ nsView: FileDragSourceView, context: Context) {
        nsView.fileURLs = fileURLs
        nsView.onDragBegan = onDragBegan
        nsView.onDragEnded = onDragEnded
    }
}

@MainActor
final class FileDragSourceView: NSView, NSDraggingSource {
    var fileURLs: [URL]
    var onDragBegan: () -> Void
    var onDragEnded: (Bool) -> Void

    private var hasStartedDrag = false

    init(
        fileURLs: [URL],
        onDragBegan: @escaping () -> Void,
        onDragEnded: @escaping (Bool) -> Void
    ) {
        self.fileURLs = fileURLs
        self.onDragBegan = onDragBegan
        self.onDragEnded = onDragEnded
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        hasStartedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag,
              !fileURLs.isEmpty,
              fileURLs.allSatisfy({
                  FileManager.default.fileExists(atPath: $0.path)
              }) else { return }
        hasStartedDrag = true
        onDragBegan()

        let draggingItems = fileURLs.enumerated().map { index, fileURL in
            let draggingItem = NSDraggingItem(
                pasteboardWriter: FileDragPayload.pasteboardWriter(for: fileURL)
            )
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = NSSize(width: 48, height: 48)
            let stackOffset = CGFloat(min(index, 3)) * 3
            let dragFrame = NSRect(
                x: bounds.midX - 24 + stackOffset,
                y: bounds.midY - 24 - stackOffset,
                width: 48,
                height: 48
            )
            draggingItem.setDraggingFrame(dragFrame, contents: icon)
            return draggingItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        hasStartedDrag = false
        onDragEnded(FileDragPayload.wasAccepted(operation))
    }
}
