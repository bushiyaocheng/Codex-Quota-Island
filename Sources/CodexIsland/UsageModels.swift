import Foundation

struct UsageWindow: Codable, Equatable, Sendable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int?

    var remainingPercent: Int {
        min(100, max(0, 100 - usedPercent))
    }

    var resetDate: Date? {
        resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    func remainingResetText(at now: Date) -> String {
        guard let resetDate else { return "--" }
        let seconds = max(0, resetDate.timeIntervalSince(now))
        if seconds >= 2 * 86_400 {
            return "\(Int(seconds / 86_400))d"
        }
        if seconds >= 3_600 {
            return "\(Int(seconds / 3_600))h"
        }
        return "\(Int(ceil(seconds / 60)))m"
    }
}

enum QuotaWindowKind: Equatable, Sendable {
    case fiveHour
    case weekly
    case duration(minutes: Int)
    case unknown

    init(durationMinutes: Int?) {
        switch durationMinutes {
        case 300: self = .fiveHour
        case 10_080: self = .weekly
        case let minutes? where minutes > 0: self = .duration(minutes: minutes)
        default: self = .unknown
        }
    }

    var title: String {
        switch self {
        case .fiveHour:
            "5 小时额度"
        case .weekly:
            "本周额度"
        case let .duration(minutes) where minutes.isMultiple(of: 60):
            "\(minutes / 60) 小时额度"
        case let .duration(minutes):
            "\(minutes) 分钟额度"
        case .unknown:
            "额度窗口"
        }
    }
}

struct QuotaWindow: Equatable, Sendable {
    let kind: QuotaWindowKind
    let usage: UsageWindow
}

struct RateLimitSnapshot: Codable, Equatable, Sendable {
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let planType: String?
}

struct ResetCreditsSummary: Codable, Equatable, Sendable {
    let availableCount: Int
}

struct RateLimitsResponse: Codable, Equatable, Sendable {
    let rateLimits: RateLimitSnapshot
    let rateLimitResetCredits: ResetCreditsSummary?
}

struct UsageSnapshot: Equatable, Sendable {
    let windows: [QuotaWindow]
    let resetCredits: Int?
    let fetchedAt: Date

    var compactWindow: QuotaWindow? {
        windows.first
    }

    init?(response: RateLimitsResponse, fetchedAt: Date = Date()) {
        let positionedWindows = [response.rateLimits.primary, response.rateLimits.secondary]
            .enumerated()
            .compactMap { position, window -> (Int, UsageWindow)? in
                window.map { (position, $0) }
            }

        guard !positionedWindows.isEmpty else { return nil }

        windows = positionedWindows
            .sorted { lhs, rhs in
                let leftDuration = lhs.1.windowDurationMins ?? .max
                let rightDuration = rhs.1.windowDurationMins ?? .max
                if leftDuration == rightDuration { return lhs.0 < rhs.0 }
                return leftDuration < rightDuration
            }
            .map { _, window in
                QuotaWindow(
                    kind: QuotaWindowKind(durationMinutes: window.windowDurationMins),
                    usage: window
                )
            }
        resetCredits = response.rateLimitResetCredits?.availableCount
        self.fetchedAt = fetchedAt
    }
}

enum QuotaTone: Equatable {
    case normal
    case warning
    case critical

    init(remainingPercent: Int) {
        if remainingPercent < 10 {
            self = .critical
        } else if remainingPercent < 30 {
            self = .warning
        } else {
            self = .normal
        }
    }

}
