import Foundation

public final class SensorSnapshotWriter {

    public init() {}

    public func write(
        indoorTemperature: Double,
        indoorHumidity: Double,
        outdoorTemperature: Double,
        outdoorHumidity: Double,
        timestamp: Date = Date(),
        to url: URL
    ) throws {

        try write(
            indoorRooms: [
                SensorReading(
                    id: "stube",
                    name: "Stube",
                    measurement: ClimateMeasurement(
                        temperature: indoorTemperature,
                        humidity: indoorHumidity
                    ),
                    isPrimary: true
                )
            ],
            outdoorSensors: [
                SensorReading(
                    id: "eve-degree",
                    name: "Eve Degree",
                    measurement: ClimateMeasurement(
                        temperature: outdoorTemperature,
                        humidity: outdoorHumidity
                    ),
                    isPrimary: true
                )
            ],
            timestamp: timestamp,
            to: url
        )
    }

    public func write(
        indoorRooms: [SensorReading],
        outdoorSensors: [SensorReading],
        timestamp: Date = Date(),
        acquisition: SensorAcquisitionStatus? = nil,
        to url: URL
    ) throws {
        guard let primaryIndoor = indoorRooms.first(where: \.isPrimary) ?? indoorRooms.first,
              let primaryOutdoor = outdoorSensors.first(where: \.isPrimary) ?? outdoorSensors.first else {
            throw SensorSnapshotWriterError.missingPrimaryMeasurements
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let file = SnapshotFile(
            version: acquisition == nil ? 2 : 3,
            timestamp: ISO8601DateFormatter().string(from: timestamp),
            source: "ClimateEngineCLI",
            indoor: SnapshotMeasurement(primaryIndoor.measurement),
            outdoor: SnapshotMeasurement(primaryOutdoor.measurement),
            indoorRooms: indoorRooms.map(SnapshotSensorReading.init),
            outdoorSensors: outdoorSensors.map(SnapshotSensorReading.init),
            acquisition: acquisition
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: url, options: .atomic)
    }
}

public enum SensorSnapshotWriterError: Error {
    case missingPrimaryMeasurements
}

private struct SnapshotFile: Encodable {
    let version: Int
    let timestamp: String
    let source: String
    let indoor: SnapshotMeasurement
    let outdoor: SnapshotMeasurement
    let indoorRooms: [SnapshotSensorReading]
    let outdoorSensors: [SnapshotSensorReading]
    let acquisition: SensorAcquisitionStatus?
}

private struct SnapshotMeasurement: Encodable {
    let temperature: String
    let humidity: Double

    init(_ measurement: ClimateMeasurement) {
        temperature = String(format: "%.3f °C", measurement.temperature)
        humidity = measurement.humidity
    }
}

private struct SnapshotSensorReading: Encodable {
    let id: String
    let name: String
    let temperature: String
    let humidity: Double
    let isPrimary: Bool
    let sourceSensorID: String?
    let sourceSensorName: String?
    let isFallback: Bool

    init(_ reading: SensorReading) {
        id = reading.id
        name = reading.name
        temperature = String(format: "%.3f °C", reading.measurement.temperature)
        humidity = reading.measurement.humidity
        isPrimary = reading.isPrimary
        sourceSensorID = reading.sourceSensorID
        sourceSensorName = reading.sourceSensorName
        isFallback = reading.usesFallback
    }
}
