import AppKit
import SwiftUI

enum FileDragPayload {
    static func pasteboardWriter(for fileURL: URL) -> NSURL {
        fileURL as NSURL
    }
}

struct FileDragSource: NSViewRepresentable {
    let fileURL: URL
    let onDragBegan: () -> Void
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> FileDragSourceView {
        FileDragSourceView(
            fileURL: fileURL,
            onDragBegan: onDragBegan,
            onDragEnded: onDragEnded
        )
    }

    func updateNSView(_ nsView: FileDragSourceView, context: Context) {
        nsView.fileURL = fileURL
        nsView.onDragBegan = onDragBegan
        nsView.onDragEnded = onDragEnded
    }
}

@MainActor
final class FileDragSourceView: NSView, NSDraggingSource {
    var fileURL: URL
    var onDragBegan: () -> Void
    var onDragEnded: () -> Void

    private var hasStartedDrag = false

    init(
        fileURL: URL,
        onDragBegan: @escaping () -> Void,
        onDragEnded: @escaping () -> Void
    ) {
        self.fileURL = fileURL
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
              FileManager.default.fileExists(atPath: fileURL.path) else { return }
        hasStartedDrag = true
        onDragBegan()

        let draggingItem = NSDraggingItem(
            pasteboardWriter: FileDragPayload.pasteboardWriter(for: fileURL)
        )
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 48, height: 48)
        let dragFrame = NSRect(
            x: bounds.midX - 24,
            y: bounds.midY - 24,
            width: 48,
            height: 48
        )
        draggingItem.setDraggingFrame(dragFrame, contents: icon)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
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
        onDragEnded()
    }
}
