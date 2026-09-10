import Foundation

public struct VentilationSession: Codable, Equatable, Sendable {
    public let version: Int
    public let startedAt: Date
    public let expiresAt: Date

    public init(
        version: Int = 1,
        startedAt: Date,
        expiresAt: Date
    ) {
        self.version = version
        self.startedAt = startedAt
        self.expiresAt = expiresAt
    }

    public static func start(
        at date: Date = Date(),
        duration: TimeInterval = 10 * 60
    ) -> VentilationSession {
        VentilationSession(
            startedAt: date,
            expiresAt: date.addingTimeInterval(duration)
        )
    }

    public static func stopped(at date: Date = Date()) -> VentilationSession {
        VentilationSession(startedAt: date, expiresAt: date)
    }

    public func isActive(at date: Date = Date()) -> Bool {
        date >= startedAt && date < expiresAt
    }

    public func remainingSeconds(at date: Date = Date()) -> Int {
        guard isActive(at: date) else { return 0 }
        return max(0, Int(ceil(expiresAt.timeIntervalSince(date))))
    }
}
