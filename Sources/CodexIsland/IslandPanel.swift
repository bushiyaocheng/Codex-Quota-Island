import AppKit

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
