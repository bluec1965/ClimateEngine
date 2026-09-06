import Foundation

public struct AdditionalSensorSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let source: String
    public let sensors: [AdditionalSensorReading]
    public let acquisition: SensorAcquisitionStatus?

    public init(
        version: Int = 1,
        timestamp: Date,
        source: String = "HomeKit via ClimateEngine Additional Sensor Connector",
        sensors: [AdditionalSensorReading],
        acquisition: SensorAcquisitionStatus? = nil
    ) {
        self.version = version
        self.timestamp = timestamp
        self.source = source
        self.sensors = sensors
        self.acquisition = acquisition
    }

    public func availabilityMessage(status: SensorAcquisitionStatus?, now: Date = Date()) -> String? {
        let status = status.flatMap { $0.timestamp >= timestamp ? $0 : nil } ?? acquisition
        if let status, !status.accepted, status.timestamp >= timestamp { return status.message }
        let age = now.timeIntervalSince(timestamp)
        guard age >= -30, age <= 12 * 60 else {
            return "Zusatzmessung veraltet · keine aktuellen Zusatzsensorwerte."
        }
        let missing = status?.sensors.filter { $0.measurement == nil } ?? []
        return missing.isEmpty ? nil : "Nicht verfügbar: " + missing.map(\.name).joined(separator: ", ")
    }

    public func currentSensors(status: SensorAcquisitionStatus?, now: Date = Date()) -> [AdditionalSensorReading] {
        let status = status.flatMap { $0.timestamp >= timestamp ? $0 : nil } ?? acquisition
        let age = now.timeIntervalSince(timestamp)
        if age < -30 || age > 12 * 60 { return [] }
        if let status, !status.accepted, status.timestamp >= timestamp { return [] }
        return sensors
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
