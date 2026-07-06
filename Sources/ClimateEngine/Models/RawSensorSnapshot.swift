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
