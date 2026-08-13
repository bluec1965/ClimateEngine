import Foundation

public enum WeatherAdvisoryKind: String, Codable, Equatable, Sendable {
    case rain
    case wind
    case rainAndWind
}

public struct WeatherAdvisory: Codable, Equatable, Sendable {
    public let kind: WeatherAdvisoryKind
    public let message: String

    public init(kind: WeatherAdvisoryKind, message: String) {
        self.kind = kind
        self.message = message
    }
}

public struct RecommendationSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let analysis: VentilationAnalysis
    public let weatherAdvisory: WeatherAdvisory?
    public let isTransitionPending: Bool

    public init(
        version: Int = 1,
        timestamp: Date,
        analysis: VentilationAnalysis,
        weatherAdvisory: WeatherAdvisory? = nil,
        isTransitionPending: Bool = false
    ) {
        self.version = version
        self.timestamp = timestamp
        self.analysis = analysis
        self.weatherAdvisory = weatherAdvisory
        self.isTransitionPending = isTransitionPending
    }
}

public struct RecommendationMeasurementSample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let indoor: ClimateMeasurement
    public let outdoor: ClimateMeasurement

    public init(timestamp: Date, indoor: ClimateMeasurement, outdoor: ClimateMeasurement) {
        self.timestamp = timestamp
        self.indoor = indoor
        self.outdoor = outdoor
    }
}

public struct RecommendationStabilityState: Codable, Equatable, Sendable {
    public let samples: [RecommendationMeasurementSample]
    public let effectiveRecommendation: VentilationRecommendation
    public let candidateRecommendation: VentilationRecommendation?
    public let candidateSince: Date?
    public let notifiedWeatherAdvisory: WeatherAdvisoryKind?

    public init(
        samples: [RecommendationMeasurementSample],
        effectiveRecommendation: VentilationRecommendation,
        candidateRecommendation: VentilationRecommendation? = nil,
        candidateSince: Date? = nil,
        notifiedWeatherAdvisory: WeatherAdvisoryKind? = nil
    ) {
        self.samples = samples
        self.effectiveRecommendation = effectiveRecommendation
        self.candidateRecommendation = candidateRecommendation
        self.candidateSince = candidateSince
        self.notifiedWeatherAdvisory = notifiedWeatherAdvisory
    }
}
