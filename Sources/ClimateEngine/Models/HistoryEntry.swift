import Foundation

public struct HistoryEntry: Codable {
    public let timestamp: Date

    public let indoorTemperature: Double
    public let indoorHumidity: Double
    public let indoorAbsoluteHumidity: Double
    public let indoorDewPoint: Double

    public let outdoorTemperature: Double
    public let outdoorHumidity: Double
    public let outdoorAbsoluteHumidity: Double
    public let outdoorDewPoint: Double

    public let recommendation: String
    public let notificationSent: Bool
    public let explanation: String

    public init(
        timestamp: Date,
        indoorTemperature: Double,
        indoorHumidity: Double,
        indoorAbsoluteHumidity: Double,
        indoorDewPoint: Double,
        outdoorTemperature: Double,
        outdoorHumidity: Double,
        outdoorAbsoluteHumidity: Double,
        outdoorDewPoint: Double,
        recommendation: String,
        notificationSent: Bool,
        explanation: String,
    ) {
        self.timestamp = timestamp
        self.indoorTemperature = indoorTemperature
        self.indoorHumidity = indoorHumidity
        self.indoorAbsoluteHumidity = indoorAbsoluteHumidity
        self.indoorDewPoint = indoorDewPoint
        self.outdoorTemperature = outdoorTemperature
        self.outdoorHumidity = outdoorHumidity
        self.outdoorAbsoluteHumidity = outdoorAbsoluteHumidity
        self.outdoorDewPoint = outdoorDewPoint
        self.recommendation = recommendation
        self.notificationSent = notificationSent
        self.explanation = explanation
    }
}
