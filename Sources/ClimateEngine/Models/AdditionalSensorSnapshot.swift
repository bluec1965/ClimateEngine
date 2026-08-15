import Foundation

public struct AdditionalSensorSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let source: String
    public let sensors: [AdditionalSensorReading]

    public init(
        version: Int = 1,
        timestamp: Date,
        source: String = "HomeKit via ClimateEngine Additional Sensor Connector",
        sensors: [AdditionalSensorReading]
    ) {
        self.version = version
        self.timestamp = timestamp
        self.source = source
        self.sensors = sensors
    }
}

public struct AdditionalSensorReading: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let roomID: String
    public let roomName: String
    public let measurement: ClimateMeasurement

    public init(
        id: String,
        name: String,
        roomID: String,
        roomName: String,
        measurement: ClimateMeasurement
    ) {
        self.id = id
        self.name = name
        self.roomID = roomID
        self.roomName = roomName
        self.measurement = measurement
    }
}
