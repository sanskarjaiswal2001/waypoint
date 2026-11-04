import Foundation

/// Restarts a stalled location stream without treating cached coordinates as fresh.
public struct LocationUpdateWatchdog {
    public static let maximumFixAge: TimeInterval = 15
    private static let retryInterval: TimeInterval = 30
    private var lastAttempt: Date?

    public init() {}

    public static func isFresh(_ timestamp: Date, at now: Date = Date()) -> Bool {
        abs(timestamp.timeIntervalSince(now)) < maximumFixAge
    }

    public mutating func started(at now: Date = Date()) { lastAttempt = now }
    public mutating func stopped() { lastAttempt = nil }

    public mutating func shouldRestart(fixTimestamp: Date?, at now: Date = Date()) -> Bool {
        guard let lastAttempt, now.timeIntervalSince(lastAttempt) >= Self.retryInterval else { return false }
        if let fixTimestamp, Self.isFresh(fixTimestamp, at: now) { return false }
        self.lastAttempt = now
        return true
    }
}
