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
        let days = UsageWindow(usedPercent: 0, windowDurationMins: 10_080, resetsAt: 1_000_000 + 6 * 86_400 + 12 * 3_600)
        let hours = UsageWindow(usedPercent: 0, windowDurationMins: 300, resetsAt: 1_000_000 + 4 * 3_600 + 35 * 60)
        let minutes = UsageWindow(usedPercent: 0, windowDurationMins: 300, resetsAt: 1_000_000 + 47 * 60 + 10)

        XCTAssertEqual(days.remainingResetText(at: now), "6d")
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

        XCTAssertEqual(snapshot.windows.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(snapshot.windows.map(\.usage.remainingPercent), [92, 93])
        XCTAssertEqual(snapshot.compactWindow?.kind, .fiveHour)
        XCTAssertEqual(snapshot.resetCredits, 2)
        XCTAssertEqual(response.rateLimits.planType, "plus")
    }

    func testWeeklyPrimaryWithoutSecondaryIsIdentifiedByDuration() throws {
        let weekly = UsageWindow(usedPercent: 12, windowDurationMins: 10_080, resetsAt: 1_800_000_000)
        let response = RateLimitsResponse(
            rateLimits: RateLimitSnapshot(primary: weekly, secondary: nil, planType: "plus"),
            rateLimitResetCredits: nil
        )

        let snapshot = try XCTUnwrap(UsageSnapshot(response: response))

        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows.first?.kind, .weekly)
        XCTAssertEqual(snapshot.windows.first?.kind.title, "本周额度")
        XCTAssertEqual(snapshot.compactWindow?.usage.remainingPercent, 88)
        XCTAssertNil(snapshot.resetCredits)
    }

    func testWindowsAreSortedByDurationInsteadOfServerPosition() throws {
        let weekly = UsageWindow(usedPercent: 12, windowDurationMins: 10_080, resetsAt: nil)
        let fiveHour = UsageWindow(usedPercent: 30, windowDurationMins: 300, resetsAt: nil)
        let response = RateLimitsResponse(
            rateLimits: RateLimitSnapshot(primary: weekly, secondary: fiveHour, planType: nil),
            rateLimitResetCredits: ResetCreditsSummary(availableCount: 0)
        )

        let snapshot = try XCTUnwrap(UsageSnapshot(response: response))

        XCTAssertEqual(snapshot.windows.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(snapshot.compactWindow?.kind, .fiveHour)
        XCTAssertEqual(snapshot.resetCredits, 0)
    }

    func testUnknownWindowDurationsGetTruthfulGeneratedTitles() {
        XCTAssertEqual(QuotaWindowKind(durationMinutes: 1_440).title, "24 小时额度")
        XCTAssertEqual(QuotaWindowKind(durationMinutes: 90).title, "90 分钟额度")
        XCTAssertEqual(QuotaWindowKind(durationMinutes: nil).title, "额度窗口")
    }
}

final class PanelViewStateTests: XCTestCase {
    @MainActor
    func testExpandedHeightTracksVisibleContent() {
        let state = PanelViewState()

        state.updateContent(windowCount: 2, showsResetCredits: true)
        XCTAssertEqual(state.expandedHeight, 244)

        state.updateContent(windowCount: 1, showsResetCredits: true)
        XCTAssertEqual(state.expandedHeight, 195)

        state.updateContent(windowCount: 1, showsResetCredits: false)
        XCTAssertEqual(state.expandedHeight, 161)

        state.updateContent(windowCount: 3, showsResetCredits: true)
        XCTAssertEqual(state.expandedHeight, 293)
    }

    func testExpansionPreferenceUsesOnePersistedMode() throws {
        let suiteName = "ExpansionPreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(ExpansionPreference.mode(in: defaults), .hover)

        ExpansionPreference.select(.click, in: defaults)
        XCTAssertEqual(ExpansionPreference.mode(in: defaults), .click)
        XCTAssertTrue(defaults.bool(forKey: "clickExpansionEnabled"))
        XCTAssertFalse(defaults.bool(forKey: "hoverExpansionEnabled"))

        ExpansionPreference.select(.hover, in: defaults)
        XCTAssertEqual(ExpansionPreference.mode(in: defaults), .hover)
        XCTAssertFalse(defaults.bool(forKey: "clickExpansionEnabled"))
        XCTAssertTrue(defaults.bool(forKey: "hoverExpansionEnabled"))
    }

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
