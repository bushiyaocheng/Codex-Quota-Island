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
    private var isStarted = false
    private var isConnecting = false
    private var isRefreshing = false
    private var nextRetryAt = Date.distantPast
    private var retryDelay: TimeInterval = 15

    func start() {
        guard !isStarted else { return }
        isStarted = true
        observeWorkspaceChanges()
        evaluateCodexProcess()
        monitorTimer = .scheduledTimer(
            timeInterval: 30,
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
        monitorTimer = nil
        refreshTimer = nil
        clockTimer = nil
        let center = NSWorkspace.shared.notificationCenter
        center.removeObserver(self)
        isStarted = false
        isConnecting = false
        isRefreshing = false
        client.stop()
    }

    func refresh() {
        guard let installation = activeInstallation,
              !isConnecting,
              !isRefreshing else { return }
        isRefreshing = true
        client.readRateLimits { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeInstallation == installation else { return }
                self.isRefreshing = false
                self.apply(result)
            }
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

    @objc private func handleWorkspaceChange() {
        evaluateCodexProcess()
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
        isConnecting = false
        isRefreshing = false
        client.stop()

        guard let installation else {
            isConnecting = false
            nextRetryAt = .distantPast
            retryDelay = 15
            state = .hidden
            snapshot = nil
            AppLog.usage.info("Codex is not running; hiding island")
            return
        }

        connect(to: installation)
    }

    private func connect(to installation: CodexInstallation) {
        state = .loading
        isConnecting = true
        isRefreshing = false
        AppLog.usage.info("Connecting to Codex process \(installation.processIdentifier, privacy: .public)")
        client.start(
            executableURL: installation.serverURL,
            onDisconnect: { [weak self] error in
                Task { @MainActor in
                    self?.handleUnexpectedDisconnect(error, from: installation)
                }
            }
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.activeInstallation == installation else { return }
                self.isConnecting = false
                switch result {
                case .success:
                    AppLog.usage.info("Connected to Codex")
                    self.retryDelay = 15
                    self.nextRetryAt = .distantPast
                    self.refresh()
                case let .failure(error):
                    AppLog.usage.error("Connection failed: \(error.localizedDescription, privacy: .private)")
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
                state = .stale("Codex 没有返回额度窗口")
                return
            }
            self.snapshot = snapshot
            state = .ready
            AppLog.usage.info("Usage refreshed")
        case let .failure(error):
            AppLog.usage.error("Refresh failed: \(error.localizedDescription, privacy: .private)")
            state = .stale(error.localizedDescription)
            scheduleRetry()
        }
    }

    private func handleUnexpectedDisconnect(_ error: Error, from installation: CodexInstallation) {
        guard activeInstallation == installation, !isConnecting else { return }
        AppLog.usage.notice("Codex app-server disconnected; scheduling retry")
        isRefreshing = false
        state = .stale(error.localizedDescription)
        scheduleRetry()
    }

    private func observeWorkspaceChanges() {
        let center = NSWorkspace.shared.notificationCenter
        [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ].forEach { name in
            center.addObserver(
                self,
                selector: #selector(handleWorkspaceChange),
                name: name,
                object: nil
            )
        }
    }

    private func scheduleRetry() {
        nextRetryAt = Date().addingTimeInterval(retryDelay)
        retryDelay = min(retryDelay * 2, 300)
    }
}
