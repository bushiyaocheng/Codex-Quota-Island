import Foundation
import IOKit.pwr_mgt

protocol SleepAssertionManaging {
    func acquireAssertion() throws -> UInt32
    func releaseAssertion(_ assertionID: UInt32)
}

struct IOPMSleepAssertionManager: SleepAssertionManaging {
    func acquireAssertion() throws -> UInt32 {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Codex Island keeps Codex tasks running while allowing display sleep" as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw SleepAssertionError(code: result)
        }
        return assertionID
    }

    func releaseAssertion(_ assertionID: UInt32) {
        IOPMAssertionRelease(IOPMAssertionID(assertionID))
    }
}

private struct SleepAssertionError: LocalizedError {
    let code: IOReturn

    var errorDescription: String? {
        "无法启用防休眠（IOKit 错误 \(code)）"
    }
}

@MainActor
final class SleepPreventionController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    private let assertionManager: any SleepAssertionManaging
    private var assertionID: UInt32?

    init(assertionManager: any SleepAssertionManaging = IOPMSleepAssertionManager()) {
        self.assertionManager = assertionManager
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            acquireAssertion()
        } else {
            releaseAssertion()
            errorMessage = nil
        }
    }

    func shutdown() {
        releaseAssertion()
    }

    private func acquireAssertion() {
        guard assertionID == nil else {
            isEnabled = true
            return
        }

        do {
            let newAssertionID = try assertionManager.acquireAssertion()
            assertionID = newAssertionID
            isEnabled = true
            errorMessage = nil
            AppLog.power.info("Preventing idle system sleep; display sleep remains system-controlled")
        } catch {
            isEnabled = false
            errorMessage = error.localizedDescription
            AppLog.power.error("Failed to prevent idle system sleep: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func releaseAssertion() {
        guard let assertionID else {
            isEnabled = false
            return
        }

        assertionManager.releaseAssertion(assertionID)
        self.assertionID = nil
        isEnabled = false
        AppLog.power.info("Restored system-controlled idle sleep")
    }
}
