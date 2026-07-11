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
