import Foundation

public struct BiasCalibrationDocument: Codable, Equatable, Sendable {
    public let version: Int
    public let generatedAt: Date
    public let windowDays: Int
    public let profiles: [BiasCalibrationProfile]

    public init(version: Int = 1, generatedAt: Date, windowDays: Int = 14, profiles: [BiasCalibrationProfile]) {
        self.version = version
        self.generatedAt = generatedAt
        self.windowDays = windowDays
        self.profiles = profiles
    }

    public func profile(roomID: String) -> BiasCalibrationProfile? {
        profiles.first { $0.roomID == roomID }
    }
}

public struct BiasCalibrationProfile: Codable, Equatable, Sendable {
    public let roomID: String
    public let baselineSensorID: String
    public let adjustedSensorID: String
    public let temperatureAdjustment: Double
    public let relativeHumidityAdjustment: Double
    public let sampleCount: Int
    public let analysisPeriod: String
    public let temperatureMAD: Double?
    public let humidityMAD: Double?
    public let isProvisional: Bool
    public let caveat: String?
}

public struct BiasCalibrationStore {
    public init() {}

    public func load(from url: URL) throws -> BiasCalibrationDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BiasCalibrationDocument.self, from: Data(contentsOf: url))
    }
}
