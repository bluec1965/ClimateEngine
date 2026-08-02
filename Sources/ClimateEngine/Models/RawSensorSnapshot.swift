import Foundation

struct RawSensorSnapshot: Decodable {
    let version: Int
    let timestamp: String
    let source: String
    let indoor: RawClimateMeasurement
    let outdoor: RawClimateMeasurement
    let indoorRooms: [RawSensorReading]?
    let outdoorSensors: [RawSensorReading]?
}

struct RawClimateMeasurement: Decodable {
    let temperature: String
    let humidity: Double
}

struct RawSensorReading: Decodable {
    let id: String
    let name: String
    let temperature: String
    let humidity: Double
    let isPrimary: Bool?
}
extension RawSensorSnapshot {

    func toSensorSnapshot() throws -> SensorSnapshot {
        guard let measurementTime = ISO8601DateFormatter().date(from: timestamp) else {
            throw SensorSnapshotLoaderError.invalidJSON(
                "Messzeitpunkt ist kein gültiger ISO-8601-Zeitstempel: \(timestamp)"
            )
        }

        let primaryIndoor = ClimateMeasurement(
            temperature: try indoor.temperatureValue(),
            humidity: indoor.humidity
        )
        let primaryOutdoor = ClimateMeasurement(
            temperature: try outdoor.temperatureValue(),
            humidity: outdoor.humidity
        )

        return SensorSnapshot(
            version: version,
            timestamp: measurementTime,
            source: source,
            indoor: primaryIndoor,
            outdoor: primaryOutdoor,
            indoorRooms: try indoorRooms?.map { try $0.toSensorReading() } ?? [],
            outdoorSensors: try outdoorSensors?.map { try $0.toSensorReading() } ?? []
        )
    }
}

extension RawClimateMeasurement {

    func temperatureValue() throws -> Double {

        let cleaned = temperature
            .replacingOccurrences(of: "°C", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let value = Double(cleaned) else {
            throw SensorSnapshotLoaderError.invalidJSON(
                "Temperaturwert ist keine Zahl: \(temperature)"
            )
        }

        return value
    }
}

extension RawSensorReading {
    func toSensorReading() throws -> SensorReading {
        let rawMeasurement = RawClimateMeasurement(
            temperature: temperature,
            humidity: humidity
        )
        return SensorReading(
            id: id,
            name: name,
            measurement: ClimateMeasurement(
                temperature: try rawMeasurement.temperatureValue(),
                humidity: humidity
            ),
            isPrimary: isPrimary ?? false
        )
    }
}
