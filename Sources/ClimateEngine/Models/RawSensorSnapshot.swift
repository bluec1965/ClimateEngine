import Foundation

struct RawSensorSnapshot: Decodable {
    let version: Int
    let timestamp: String
    let source: String
    let indoor: RawClimateMeasurement
    let outdoor: RawClimateMeasurement
}

struct RawClimateMeasurement: Decodable {
    let temperature: String
    let humidity: Double
}
extension RawSensorSnapshot {

    func toSensorSnapshot() throws -> SensorSnapshot {
        guard let measurementTime = ISO8601DateFormatter().date(from: timestamp) else {
            throw SensorSnapshotLoaderError.invalidJSON(
                "Messzeitpunkt ist kein gültiger ISO-8601-Zeitstempel: \(timestamp)"
            )
        }

        return SensorSnapshot(
            version: version,
            timestamp: measurementTime,
            source: source,
            indoor: ClimateMeasurement(
                temperature: try indoor.temperatureValue(),
                humidity: indoor.humidity
            ),
            outdoor: ClimateMeasurement(
                temperature: try outdoor.temperatureValue(),
                humidity: outdoor.humidity
            )
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
