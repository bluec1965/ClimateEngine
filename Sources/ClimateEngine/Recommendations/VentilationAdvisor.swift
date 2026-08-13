import Foundation

public enum VentilationRecommendation: String, Codable, Equatable, Sendable {
    case ventilate
    case neutral
    case closeWindows

    public var title: String {
        switch self {
        case .ventilate:
            return "Ventilate"
        case .neutral:
            return "Neutral"
        case .closeWindows:
            return "Close windows"
        }
    }
}

public struct VentilationAnalysis: Codable, Equatable, Sendable {
    public let recommendation: VentilationRecommendation
    public let indoorAbsoluteHumidity: Double
    public let outdoorAbsoluteHumidity: Double
    public let absoluteHumidityDifference: Double
    public let explanation: String
    public let indoorTemperature: Double
    public let outdoorTemperature: Double

    public init(
        recommendation: VentilationRecommendation,
        indoorAbsoluteHumidity: Double,
        outdoorAbsoluteHumidity: Double,
        absoluteHumidityDifference: Double,
        explanation: String,
        indoorTemperature: Double,
        outdoorTemperature: Double
    ) {
        self.recommendation = recommendation
        self.indoorAbsoluteHumidity = indoorAbsoluteHumidity
        self.outdoorAbsoluteHumidity = outdoorAbsoluteHumidity
        self.absoluteHumidityDifference = absoluteHumidityDifference
        self.explanation = explanation
        self.indoorTemperature = indoorTemperature
        self.outdoorTemperature = outdoorTemperature
    }
}

public enum VentilationAdvisor {

    public static func analyze(snapshot: SensorSnapshot) -> VentilationAnalysis {
        analyze(indoor: snapshot.indoor, outdoor: snapshot.outdoor)
    }

    public static func analyze(
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement
    ) -> VentilationAnalysis {
        let indoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: indoor.temperature,
            relativeHumidity: indoor.humidity
        )

        let outdoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: outdoor.temperature,
            relativeHumidity: outdoor.humidity
        )

        let difference = outdoorAbsoluteHumidity - indoorAbsoluteHumidity

        let outdoorIsClearlyDrier = difference < -0.3
        let outdoorIsClearlyMoreHumid = difference > 0.3
        let outdoorIsCooler = outdoor.temperature < indoor.temperature
        let outdoorIsWarmerOrEqual = outdoor.temperature >= indoor.temperature

        let recommendation: VentilationRecommendation
        let explanation: String

        if outdoorIsClearlyDrier && outdoorIsCooler {
            recommendation = .ventilate
            explanation = "Die Aussenluft ist kühler und trockener als die Raumluft."
        } else if outdoorIsClearlyDrier && outdoorIsWarmerOrEqual {
            recommendation = .closeWindows
            explanation = "Die Aussenluft ist zwar trockener, aber wärmer als die Raumluft."
        } else if outdoorIsClearlyMoreHumid && outdoorIsCooler {
            recommendation = .closeWindows
            explanation = "Die Aussenluft ist zwar kühler, enthält aber mehr Feuchtigkeit als die Raumluft."
        } else if outdoorIsClearlyMoreHumid && outdoorIsWarmerOrEqual {
            recommendation = .closeWindows
            explanation = "Die Aussenluft ist wärmer und feuchter als die Raumluft."
        } else if outdoorIsWarmerOrEqual {
            recommendation = .closeWindows
            explanation = "Die Aussenluft ist wärmer als die Raumluft."
        } else {
            recommendation = .neutral
            explanation = "Innen- und Aussenluft unterscheiden sich nur gering."
        }

        return VentilationAnalysis(
            recommendation: recommendation,
            indoorAbsoluteHumidity: indoorAbsoluteHumidity,
            outdoorAbsoluteHumidity: outdoorAbsoluteHumidity,
            absoluteHumidityDifference: difference,
            explanation: explanation,
            indoorTemperature: indoor.temperature,
            outdoorTemperature: outdoor.temperature,

        )
    }

    public static func recommendation(for snapshot: SensorSnapshot) -> VentilationRecommendation {
        analyze(snapshot: snapshot).recommendation
    }
}
