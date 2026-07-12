import AppKit
import Combine
import CoreGraphics

@MainActor
final class NotchPanelController {
    private let usage: UsageController
    private let launchAtLogin = LaunchAtLoginController()
    private let viewState = PanelViewState()
    private let panel: IslandPanel
    private var cancellables = Set<AnyCancellable>()

    init(usage: UsageController) {
        self.usage = usage
        panel = IslandPanel(
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
        panel.panelState = viewState
        panel.usage = usage
        panel.launchAtLogin = launchAtLogin
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
            .sink { [weak self] _ in self?.layoutPanel() }
            .store(in: &cancellables)
    }

    private func updateVisibility(for state: UsageController.State) {
        switch state {
        case .hidden:
            viewState.resetInteractionExpansion()
            panel.orderOut(nil)
        case .loading, .ready, .stale:
            layoutPanel()
            panel.orderFrontRegardless()
        }
    }

    private func layoutPanel() {
        guard let screen = builtInNotchedScreen() else {
            AppLog.windowing.debug("No built-in notched display is available")
            panel.orderOut(nil)
            return
        }

        let notchWidth = resolvedNotchWidth(on: screen)
        let compactHeight = max(30, screen.safeAreaInsets.top)
        viewState.notchWidth = notchWidth
        viewState.compactHeight = compactHeight

        let width: CGFloat = notchWidth + 140
        let height = PanelViewState.expandedHeight
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
            screen.safeAreaInsets.top > 0 && isBuiltInDisplay(screen)
        }
    }

    private func isBuiltInDisplay(_ screen: NSScreen) -> Bool {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(screenNumber.uint32Value)) != 0
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
