import XCTest
@testable import CodexIsland

final class SleepPreventionControllerTests: XCTestCase {
    @MainActor
    func testEnableAndDisableAcquireAndReleaseAssertion() {
        let manager = SleepAssertionManagerMock(assertionID: 42)
        let controller = SleepPreventionController(assertionManager: manager)

        controller.setEnabled(true)

        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.errorMessage)
        XCTAssertEqual(manager.acquireCallCount, 1)

        controller.setEnabled(false)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(manager.releasedAssertionIDs, [42])
    }

    @MainActor
    func testFailedAssertionLeavesControlOffAndExposesError() {
        let manager = SleepAssertionManagerMock(error: TestError.unavailable)
        let controller = SleepPreventionController(assertionManager: manager)

        controller.setEnabled(true)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.errorMessage, "系统断言不可用")
        XCTAssertTrue(manager.releasedAssertionIDs.isEmpty)
    }

    @MainActor
    func testShutdownReleasesActiveAssertion() {
        let manager = SleepAssertionManagerMock(assertionID: 7)
        let controller = SleepPreventionController(assertionManager: manager)
        controller.setEnabled(true)

        controller.shutdown()

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(manager.releasedAssertionIDs, [7])
    }
}

private enum TestError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "系统断言不可用"
    }
}

private final class SleepAssertionManagerMock: SleepAssertionManaging {
    private let result: Result<UInt32, Error>
    private(set) var acquireCallCount = 0
    private(set) var releasedAssertionIDs: [UInt32] = []

    init(assertionID: UInt32) {
        result = .success(assertionID)
    }

    init(error: Error) {
        result = .failure(error)
    }

    func acquireAssertion() throws -> UInt32 {
        acquireCallCount += 1
        return try result.get()
    }

    func releaseAssertion(_ assertionID: UInt32) {
        releasedAssertionIDs.append(assertionID)
    }
}
