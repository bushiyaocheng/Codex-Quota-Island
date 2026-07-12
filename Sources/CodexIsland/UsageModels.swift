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
        if seconds >= 3_600 {
            return "\(Int(seconds / 3_600))h"
        }
        return "\(Int(ceil(seconds / 60)))m"
    }
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
    let fiveHour: UsageWindow
    let weekly: UsageWindow?
    let resetCredits: Int
    let fetchedAt: Date

    init?(response: RateLimitsResponse, fetchedAt: Date = Date()) {
        guard let primary = response.rateLimits.primary else { return nil }
        fiveHour = primary
        weekly = response.rateLimits.secondary
        resetCredits = response.rateLimitResetCredits?.availableCount ?? 0
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
