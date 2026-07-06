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

        SensorSnapshot(
            version: version,
            timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
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
            throw SensorSnapshotLoaderError.invalidJSON
        }

        return value
    }
}
