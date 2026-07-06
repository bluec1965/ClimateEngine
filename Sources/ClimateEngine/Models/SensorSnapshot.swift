import Foundation

public struct SensorSnapshot: Equatable {
    public let version: Int
    public let timestamp: Date
    public let source: String
    public let indoor: ClimateMeasurement
    public let outdoor: ClimateMeasurement
}

public struct ClimateMeasurement: Equatable {
    public let temperature: Double
    public let humidity: Double
}
