import AppKit
import Combine
import SwiftUI

@MainActor
private final class IslandHostingView: NSHostingView<NotchRootView> {
    private let panelState: PanelViewState

    init(rootView: NotchRootView, panelState: PanelViewState) {
        self.panelState = panelState
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: NotchRootView) {
        fatalError("Use init(rootView:panelState:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let activeHeight = panelState.isExpanded ? bounds.height : panelState.compactHeight
        guard point.y >= bounds.height - activeHeight else { return nil }
        return super.hitTest(point)
    }
}

@MainActor
final class NotchPanelController {
    private let usage: UsageController
    private let viewState = PanelViewState()
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()

    init(usage: UsageController) {
        self.usage = usage
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        let rootView = NotchRootView(usage: usage, panel: viewState)
        panel.contentView = IslandHostingView(rootView: rootView, panelState: viewState)

        usage.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateVisibility(for: state)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.layoutPanel(animated: false) }
            .store(in: &cancellables)
    }

    private func updateVisibility(for state: UsageController.State) {
        switch state {
        case .hidden:
            if !viewState.startsExpanded { viewState.isExpanded = false }
            panel.orderOut(nil)
        case .loading, .ready, .stale:
            layoutPanel(animated: false)
            panel.orderFrontRegardless()
        }
    }

    private func layoutPanel(animated _: Bool) {
        guard let screen = builtInNotchedScreen() else {
            panel.orderOut(nil)
            return
        }

        let notchWidth = resolvedNotchWidth(on: screen)
        let compactHeight = max(30, screen.safeAreaInsets.top)
        viewState.notchWidth = notchWidth
        viewState.compactHeight = compactHeight

        let width: CGFloat = notchWidth + 140
        let height: CGFloat = 244
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )

        panel.setFrame(frame, display: true)
    }

    private func builtInNotchedScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.safeAreaInsets.top > 0
                && (screen.localizedName.lowercased().contains("built-in")
                    || screen.localizedName.contains("内建")
                    || screen == NSScreen.main)
        }
    }

    private func resolvedNotchWidth(on screen: NSScreen) -> CGFloat {
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            if width > 80 { return width }
        }
        return 180
    }
}
