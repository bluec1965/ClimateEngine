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
    public let indoorRooms: [SensorReading]
    public let outdoorSensors: [SensorReading]

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
        indoorRooms: [SensorReading] = [],
        outdoorSensors: [SensorReading] = []
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
        self.indoorRooms = indoorRooms
        self.outdoorSensors = outdoorSensors
    }

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case indoorTemperature
        case indoorHumidity
        case indoorAbsoluteHumidity
        case indoorDewPoint
        case outdoorTemperature
        case outdoorHumidity
        case outdoorAbsoluteHumidity
        case outdoorDewPoint
        case recommendation
        case notificationSent
        case explanation
        case indoorRooms
        case outdoorSensors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        timestamp = try container.decode(Date.self, forKey: .timestamp)

        indoorTemperature = try container.decode(Double.self, forKey: .indoorTemperature)
        indoorHumidity = try container.decode(Double.self, forKey: .indoorHumidity)
        indoorAbsoluteHumidity = try container.decode(Double.self, forKey: .indoorAbsoluteHumidity)
        indoorDewPoint = try container.decode(Double.self, forKey: .indoorDewPoint)

        outdoorTemperature = try container.decode(Double.self, forKey: .outdoorTemperature)
        outdoorHumidity = try container.decode(Double.self, forKey: .outdoorHumidity)
        outdoorAbsoluteHumidity = try container.decode(Double.self, forKey: .outdoorAbsoluteHumidity)
        outdoorDewPoint = try container.decode(Double.self, forKey: .outdoorDewPoint)

        recommendation = try container.decode(String.self, forKey: .recommendation)
        notificationSent = try container.decode(Bool.self, forKey: .notificationSent)

        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
            ?? "Keine Begründung verfügbar."
        indoorRooms = try container.decodeIfPresent([SensorReading].self, forKey: .indoorRooms)
            ?? []
        outdoorSensors = try container.decodeIfPresent([SensorReading].self, forKey: .outdoorSensors)
            ?? []
    }
}
