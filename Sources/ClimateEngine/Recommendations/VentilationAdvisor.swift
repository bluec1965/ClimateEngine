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

        let recommendation: VentilationRecommendation

        if difference < -0.3 {
            recommendation = .ventilate
        } else if difference > 0.3 {
            recommendation = .closeWindows
        } else {
            recommendation = .neutral
        }

        return VentilationAnalysis(
            recommendation: recommendation,
            indoorAbsoluteHumidity: indoorAbsoluteHumidity,
            outdoorAbsoluteHumidity: outdoorAbsoluteHumidity,
            absoluteHumidityDifference: difference
        )
    }

    public static func recommendation(for snapshot: SensorSnapshot) -> VentilationRecommendation {
        analyze(snapshot: snapshot).recommendation
    }
}
