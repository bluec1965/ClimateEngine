import Foundation

public struct HistoryEvent: Equatable {
    public let timestamp: Date
    public let recommendation: String
    public let notificationSent: Bool
    public let explanation: String

    public init(
        timestamp: Date,
        recommendation: String,
        notificationSent: Bool,
        explanation: String
    ) {
        self.timestamp = timestamp
        self.recommendation = recommendation
        self.notificationSent = notificationSent
        self.explanation = explanation
    }
}
