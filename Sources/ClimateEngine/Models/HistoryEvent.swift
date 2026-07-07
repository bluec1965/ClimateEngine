import Foundation

public struct HistoryEvent: Equatable {
    public let timestamp: Date
    public let recommendation: String
    public let notificationSent: Bool

    public init(
        timestamp: Date,
        recommendation: String,
        notificationSent: Bool
    ) {
        self.timestamp = timestamp
        self.recommendation = recommendation
        self.notificationSent = notificationSent
    }
}
