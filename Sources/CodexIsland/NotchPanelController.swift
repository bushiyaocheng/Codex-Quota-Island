import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandPanel: NSPanel {
    weak var panelState: PanelViewState?
    weak var usage: UsageController?
    weak var launchAtLogin: LaunchAtLoginController?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .rightMouseDown, isInsideCompactBar(event) {
            showCompactMenu(for: event)
            return
        }

        guard event.type == .leftMouseDown || event.type == .leftMouseUp,
              ExpansionPreference.mode == .click,
              isInsideCompactBar(event) else {
            super.sendEvent(event)
            return
        }

        if event.type == .leftMouseDown {
            panelState?.toggleClickExpansion()
        }
        // The panel owns physical left clicks in the compact bar. Swallow both phases
        // so the SwiftUI Button cannot receive only mouse-up and toggle a second time.
    }

    func makeCompactMenu() -> NSMenu {
        let menu = NSMenu()

        let clickItem = NSMenuItem(
            title: "鼠标点击展开",
            action: #selector(selectClickExpansionMode),
            keyEquivalent: ""
        )
        clickItem.target = self
        clickItem.state = ExpansionPreference.mode == .click ? .on : .off
        menu.addItem(clickItem)

        let hoverItem = NSMenuItem(
            title: "鼠标悬停展开",
            action: #selector(selectHoverExpansionMode),
            keyEquivalent: ""
        )
        hoverItem.target = self
        hoverItem.state = ExpansionPreference.mode == .hover ? .on : .off
        menu.addItem(hoverItem)

        menu.addItem(.separator())
        menu.addItem(menuItem(title: "立即刷新", action: #selector(refreshUsage)))

        let loginTitle = launchAtLogin?.isEnabled == true ? "关闭登录时启动" : "登录时启动"
        let loginItem = menuItem(title: loginTitle, action: #selector(toggleLaunchAtLogin))
        loginItem.isEnabled = launchAtLogin?.isAvailable == true
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(menuItem(title: "退出 Codex Island", action: #selector(terminateApplication)))
        return menu
    }

    private func showCompactMenu(for event: NSEvent) {
        guard let contentView else { return }
        NSMenu.popUpContextMenu(makeCompactMenu(), with: event, for: contentView)
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func selectClickExpansionMode() {
        selectExpansionMode(.click)
    }

    @objc private func selectHoverExpansionMode() {
        selectExpansionMode(.hover)
    }

    private func selectExpansionMode(_ mode: ExpansionMode) {
        guard ExpansionPreference.mode != mode else { return }
        ExpansionPreference.select(mode)
        panelState?.resetInteractionExpansion()
    }

    @objc private func refreshUsage() {
        usage?.refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        guard let launchAtLogin else { return }
        launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
    }

    @objc private func terminateApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func isInsideCompactBar(_ event: NSEvent) -> Bool {
        guard let contentView, let panelState else { return false }
        let point = contentView.convert(event.locationInWindow, from: nil)
        let height = min(contentView.bounds.height, panelState.compactHeight)
        let originY = contentView.isFlipped
            ? contentView.bounds.minY
            : contentView.bounds.maxY - height
        let rect = NSRect(
            x: contentView.bounds.minX,
            y: originY,
            width: contentView.bounds.width,
            height: height
        )
        return rect.contains(point)
    }
}

@MainActor
private final class IslandHostingView: NSHostingView<NotchRootView> {
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
