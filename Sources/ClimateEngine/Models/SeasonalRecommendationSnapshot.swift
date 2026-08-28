import Foundation

public enum SeasonalVentilationRecommendation: String, Codable, Equatable, Sendable {
    case extendedVentilation
    case briefVentilation
    case wait
    case keepClosed
}

public struct SeasonalRecommendationSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let sensorTimestamp: Date
    public let selectedMode: OperatingModeSelection
    public let effectiveMode: OperatingMode
    public let heatingEnabled: Bool
    public let recommendation: SeasonalVentilationRecommendation
    public let suggestedDurationMinutes: Int?
    public let suggestedStartAt: Date?
    public let indoorTemperature: Double
    public let outdoorTemperature: Double
    public let indoorRelativeHumidity: Double
    public let indoorAbsoluteHumidity: Double
    public let outdoorAbsoluteHumidity: Double
    public let comfortFloorTemperature: Double
    public let productionRecommendation: VentilationRecommendation
    public let explanation: String

    public init(
        version: Int = 1,
        timestamp: Date,
        sensorTimestamp: Date,
        selectedMode: OperatingModeSelection,
        effectiveMode: OperatingMode,
        heatingEnabled: Bool,
        recommendation: SeasonalVentilationRecommendation,
        suggestedDurationMinutes: Int? = nil,
        suggestedStartAt: Date? = nil,
        indoorTemperature: Double,
        outdoorTemperature: Double,
        indoorRelativeHumidity: Double,
        indoorAbsoluteHumidity: Double,
        outdoorAbsoluteHumidity: Double,
        comfortFloorTemperature: Double,
        productionRecommendation: VentilationRecommendation,
        explanation: String
    ) {
        self.version = version
        self.timestamp = timestamp
        self.sensorTimestamp = sensorTimestamp
        self.selectedMode = selectedMode
        self.effectiveMode = effectiveMode
        self.heatingEnabled = heatingEnabled
        self.recommendation = recommendation
        self.suggestedDurationMinutes = suggestedDurationMinutes
        self.suggestedStartAt = suggestedStartAt
        self.indoorTemperature = indoorTemperature
        self.outdoorTemperature = outdoorTemperature
        self.indoorRelativeHumidity = indoorRelativeHumidity
        self.indoorAbsoluteHumidity = indoorAbsoluteHumidity
        self.outdoorAbsoluteHumidity = outdoorAbsoluteHumidity
        self.comfortFloorTemperature = comfortFloorTemperature
        self.productionRecommendation = productionRecommendation
        self.explanation = explanation
    }
}
