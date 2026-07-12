import AppKit
import XCTest
@testable import CodexIsland

final class UsageModelsTests: XCTestCase {
    func testRemainingPercentIsInverseOfUsedPercent() {
        let window = UsageWindow(usedPercent: 8, windowDurationMins: 300, resetsAt: 1_783_793_858)
        XCTAssertEqual(window.remainingPercent, 92)
    }

    func testRemainingPercentIsClamped() {
        XCTAssertEqual(UsageWindow(usedPercent: -5, windowDurationMins: nil, resetsAt: nil).remainingPercent, 100)
        XCTAssertEqual(UsageWindow(usedPercent: 110, windowDurationMins: nil, resetsAt: nil).remainingPercent, 0)
    }

    func testQuotaThresholds() {
        XCTAssertEqual(QuotaTone(remainingPercent: 30), .normal)
        XCTAssertEqual(QuotaTone(remainingPercent: 29), .warning)
        XCTAssertEqual(QuotaTone(remainingPercent: 10), .warning)
        XCTAssertEqual(QuotaTone(remainingPercent: 9), .critical)
    }

    func testRemainingResetTextUsesHoursThenMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let hours = UsageWindow(usedPercent: 0, windowDurationMins: 300, resetsAt: 1_000_000 + 4 * 3_600 + 35 * 60)
        let minutes = UsageWindow(usedPercent: 0, windowDurationMins: 300, resetsAt: 1_000_000 + 47 * 60 + 10)

        XCTAssertEqual(hours.remainingResetText(at: now), "4h")
        XCTAssertEqual(minutes.remainingResetText(at: now), "48m")
    }

    func testRateLimitPayloadDecoding() throws {
        let json = #"""
        {
          "rateLimits": {
            "primary": { "usedPercent": 8, "windowDurationMins": 300, "resetsAt": 1783793858 },
            "secondary": { "usedPercent": 7, "windowDurationMins": 10080, "resetsAt": 1784361682 },
            "planType": "plus"
          },
          "rateLimitResetCredits": { "availableCount": 2 }
        }
        """#

        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: Data(json.utf8))
        let snapshot = try XCTUnwrap(UsageSnapshot(response: response))

        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 92)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 93)
        XCTAssertEqual(snapshot.resetCredits, 2)
        XCTAssertEqual(snapshot.planType, "plus")
    }
}

final class PanelViewStateTests: XCTestCase {
    @MainActor
    func testInteractionExpansionCanBeResetWhenModeChanges() {
        let state = PanelViewState()

        state.toggleClickExpansion()
        XCTAssertTrue(state.isExpanded)

        state.resetInteractionExpansion()
        XCTAssertFalse(state.isExpanded)

        state.setHovering(true)
        XCTAssertTrue(state.isExpanded)
        state.setHovering(false)
        XCTAssertFalse(state.isExpanded)
    }

    @MainActor
    func testPhysicalCompactBarClickTogglesExpansionAtPanelLevel() throws {
        let defaults = UserDefaults.standard
        let originalMode = defaults.object(forKey: ExpansionPreference.storageKey)
        let originalClickPreference = defaults.object(forKey: "clickExpansionEnabled")
        let originalHoverPreference = defaults.object(forKey: "hoverExpansionEnabled")
        defaults.set(ExpansionMode.click.rawValue, forKey: ExpansionPreference.storageKey)
        defer {
            if let originalMode {
                defaults.set(originalMode, forKey: ExpansionPreference.storageKey)
            } else {
                defaults.removeObject(forKey: ExpansionPreference.storageKey)
            }
            if let originalClickPreference {
                defaults.set(originalClickPreference, forKey: "clickExpansionEnabled")
            } else {
                defaults.removeObject(forKey: "clickExpansionEnabled")
            }
            if let originalHoverPreference {
                defaults.set(originalHoverPreference, forKey: "hoverExpansionEnabled")
            } else {
                defaults.removeObject(forKey: "hoverExpansionEnabled")
            }
        }

        let state = PanelViewState()
        state.compactHeight = 32
        let panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 319, height: 244),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.panelState = state
        panel.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 319, height: 244))

        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 35, y: 228),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))

        panel.sendEvent(event)
        XCTAssertTrue(state.isExpanded)

        let menu = panel.makeCompactMenu()
        XCTAssertEqual(menu.items.map(\.title), [
            "鼠标点击展开",
            "鼠标悬停展开",
            "",
            "立即刷新",
            "登录时启动",
            "",
            "退出 Codex Island"
        ])
        XCTAssertEqual(menu.items[0].state, .on)
        XCTAssertEqual(menu.items[1].state, .off)

        menu.performActionForItem(at: 1)
        XCTAssertEqual(ExpansionPreference.mode, .hover)
        XCTAssertFalse(state.isExpanded)

        let updatedMenu = panel.makeCompactMenu()
        XCTAssertEqual(updatedMenu.items[0].state, .off)
        XCTAssertEqual(updatedMenu.items[1].state, .on)
    }
}
