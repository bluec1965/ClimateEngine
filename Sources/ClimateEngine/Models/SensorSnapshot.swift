import Foundation

public struct SensorSnapshot: Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let source: String
    public let indoor: ClimateMeasurement
    public let outdoor: ClimateMeasurement
    public let indoorRooms: [SensorReading]
    public let outdoorSensors: [SensorReading]
    public let acquisition: SensorAcquisitionStatus?

    public init(
        version: Int,
        timestamp: Date,
        source: String,
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement,
        indoorRooms: [SensorReading] = [],
        outdoorSensors: [SensorReading] = [],
        acquisition: SensorAcquisitionStatus? = nil
    ) {
        self.version = version
        self.timestamp = timestamp
        self.source = source
        self.acquisition = acquisition
        self.indoor = indoor
        self.outdoor = outdoor
        self.indoorRooms = indoorRooms.isEmpty
            ? [SensorReading(id: "stube", name: "Stube", measurement: indoor, isPrimary: true)]
            : indoorRooms
        self.outdoorSensors = outdoorSensors.isEmpty
            ? [SensorReading(id: "eve-degree", name: "Eve Degree", measurement: outdoor, isPrimary: true)]
            : outdoorSensors
    }
}

public struct ClimateMeasurement: Codable, Equatable, Sendable {
    public let temperature: Double
    public let humidity: Double

    public init(temperature: Double, humidity: Double) {
        self.temperature = temperature
        self.humidity = humidity
    }
}

public struct SensorReading: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let measurement: ClimateMeasurement
    public let isPrimary: Bool
    /// The physical sensor used for this room slot. Nil means `id`/`name`.
    public let sourceSensorID: String?
    public let sourceSensorName: String?
    /// Optional for backward-compatible decoding of version 1–3 snapshots.
    public let isFallback: Bool?

    public init(
        id: String,
        name: String,
        measurement: ClimateMeasurement,
        isPrimary: Bool = false,
        sourceSensorID: String? = nil,
        sourceSensorName: String? = nil,
        isFallback: Bool = false
    ) {
        self.id = id
        self.name = name
        self.measurement = measurement
        self.isPrimary = isPrimary
        self.sourceSensorID = sourceSensorID
        self.sourceSensorName = sourceSensorName
        self.isFallback = isFallback
    }

    public var effectiveSensorID: String { sourceSensorID ?? id }
    public var effectiveSensorName: String { sourceSensorName ?? name }
    public var usesFallback: Bool { isFallback == true }
}
