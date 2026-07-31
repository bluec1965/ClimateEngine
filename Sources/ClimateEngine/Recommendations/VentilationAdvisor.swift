import Foundation

public enum VentilationRecommendation: Equatable {
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

public struct VentilationAnalysis: Equatable {
    public let recommendation: VentilationRecommendation
    public let indoorAbsoluteHumidity: Double
    public let outdoorAbsoluteHumidity: Double
    public let absoluteHumidityDifference: Double
    public let explanation: String
    public let indoorTemperature: Double
    public let outdoorTemperature: Double
}

public enum VentilationAdvisor {

    public static func analyze(snapshot: SensorSnapshot) -> VentilationAnalysis {
        let indoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: snapshot.indoor.temperature,
            relativeHumidity: snapshot.indoor.humidity
        )

        let outdoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: snapshot.outdoor.temperature,
            relativeHumidity: snapshot.outdoor.humidity
        )

        let difference = outdoorAbsoluteHumidity - indoorAbsoluteHumidity

        let outdoorIsClearlyDrier = difference < -0.3
        let outdoorIsClearlyMoreHumid = difference > 0.3
        let outdoorIsCooler = snapshot.outdoor.temperature < snapshot.indoor.temperature
        let outdoorIsWarmerOrEqual = snapshot.outdoor.temperature >= snapshot.indoor.temperature

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
            indoorTemperature: snapshot.indoor.temperature,
            outdoorTemperature: snapshot.outdoor.temperature,

        )
    }

    public static func recommendation(for snapshot: SensorSnapshot) -> VentilationRecommendation {
        analyze(snapshot: snapshot).recommendation
    }
}
