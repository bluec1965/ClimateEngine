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

public enum VentilationAdvisor {

    public static func recommendation(for snapshot: SensorSnapshot) -> VentilationRecommendation {
        let indoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: snapshot.indoor.temperature,
            relativeHumidity: snapshot.indoor.humidity
        )

        let outdoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: snapshot.outdoor.temperature,
            relativeHumidity: snapshot.outdoor.humidity
        )

        let difference = outdoorAbsoluteHumidity - indoorAbsoluteHumidity

        if difference < -0.3 {
            return .ventilate
        }

        if difference > 0.3 {
            return .closeWindows
        }

        return .neutral
    }
}
