import AppKit
import Foundation

@MainActor
final class UsageController: NSObject, ObservableObject {
    enum State: Equatable {
        case hidden
        case loading
        case ready
        case stale(String)
    }

    @Published private(set) var state: State = .hidden
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var now = Date()

    private let detector = CodexProcessDetector()
    private let client = AppServerClient()
    private var activeInstallation: CodexInstallation?
    private var monitorTimer: Timer?
    private var refreshTimer: Timer?
    private var clockTimer: Timer?
    private var isConnecting = false
    private var nextRetryAt = Date.distantPast
    private var retryDelay: TimeInterval = 15

    var isVisible: Bool { state != .hidden }

    func start() {
        evaluateCodexProcess()
        monitorTimer = .scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(handleMonitorTimer),
            userInfo: nil,
            repeats: true
        )
        refreshTimer = .scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(handleRefreshTimer),
            userInfo: nil,
            repeats: true
        )
        clockTimer = .scheduledTimer(
            timeInterval: 30,
            target: self,
            selector: #selector(handleClockTimer),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        monitorTimer?.invalidate()
        refreshTimer?.invalidate()
        clockTimer?.invalidate()
        client.stop()
    }

    func refresh() {
        guard activeInstallation != nil, !isConnecting else { return }
        client.readRateLimits { [weak self] result in
            Task { @MainActor in self?.apply(result) }
        }
    }

    @objc private func handleMonitorTimer() {
        evaluateCodexProcess()
    }

    @objc private func handleRefreshTimer() {
        refresh()
    }

    @objc private func handleClockTimer() {
        now = Date()
    }

    private func evaluateCodexProcess() {
        let installation = detector.runningInstallation()
        if installation == activeInstallation {
            if let installation,
               case .stale = state,
               !isConnecting,
               Date() >= nextRetryAt {
                connect(to: installation)
            }
            return
        }

        activeInstallation = installation
        client.stop()

        guard let installation else {
            isConnecting = false
            nextRetryAt = .distantPast
            retryDelay = 15
            state = .hidden
            snapshot = nil
            return
        }

        connect(to: installation)
    }

    private func connect(to installation: CodexInstallation) {
        state = .loading
        isConnecting = true
        client.start(executableURL: installation.serverURL) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isConnecting = false
                switch result {
                case .success:
                    self.retryDelay = 15
                    self.nextRetryAt = .distantPast
                    self.refresh()
                case let .failure(error):
                    self.state = .stale(error.localizedDescription)
                    self.scheduleRetry()
                }
            }
        }
    }

    private func apply(_ result: Result<RateLimitsResponse, Error>) {
        switch result {
        case let .success(response):
            guard let snapshot = UsageSnapshot(response: response) else {
                state = .stale("Codex 没有返回 5 小时额度窗口")
                return
            }
            self.snapshot = snapshot
            state = .ready
        case let .failure(error):
            state = .stale(error.localizedDescription)
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        nextRetryAt = Date().addingTimeInterval(retryDelay)
        retryDelay = min(retryDelay * 2, 300)
    }
}
