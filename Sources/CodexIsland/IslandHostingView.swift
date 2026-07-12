import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandHostingView: NSHostingView<NotchRootView> {
    private let panelState: PanelViewState
    private var hoverTrackingArea: NSTrackingArea?
    private var cancellables = Set<AnyCancellable>()

    init(rootView: NotchRootView, panelState: PanelViewState) {
        self.panelState = panelState
        super.init(rootView: rootView)

        panelState.$isExpanded
            .combineLatest(panelState.$compactHeight)
            .removeDuplicates { lhs, rhs in
                lhs.0 == rhs.0 && lhs.1 == rhs.1
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTrackingAreas()
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init(rootView: NotchRootView) {
        fatalError("Use init(rootView:panelState:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: activeRect,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard activeRect.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard ExpansionPreference.mode == .hover, !panelState.startsExpanded else { return }
        panelState.setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard ExpansionPreference.mode == .hover, !panelState.startsExpanded else { return }
        panelState.setHovering(false)
    }

    private var activeRect: NSRect {
        let height = min(
            bounds.height,
            panelState.isExpanded ? PanelViewState.expandedHeight : panelState.compactHeight
        )
        let originY = isFlipped ? bounds.minY : bounds.maxY - height
        return NSRect(x: bounds.minX, y: originY, width: bounds.width, height: height)
    }
}
