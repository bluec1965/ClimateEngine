import Foundation

public enum OperatingModeSelection: String, Codable, CaseIterable, Equatable, Sendable {
    case automatic
    case summer
    case transition
}

public enum OperatingMode: String, Codable, Equatable, Sendable {
    case summer
    case transition
    case heating
}

public struct OperatingModeState: Codable, Equatable, Sendable {
    public let version: Int
    public let heatingEnabled: Bool
    public let selection: OperatingModeSelection
    public let updatedAt: Date

    public init(
        version: Int = 1,
        heatingEnabled: Bool,
        selection: OperatingModeSelection,
        updatedAt: Date
    ) {
        self.version = version
        self.heatingEnabled = heatingEnabled
        self.selection = selection
        self.updatedAt = updatedAt
    }

    public static func defaultState(now: Date = Date()) -> OperatingModeState {
        OperatingModeState(
            heatingEnabled: false,
            selection: .automatic,
            updatedAt: now
        )
    }
}

public enum OperatingModeResolver {
    public static func resolve(
        state: OperatingModeState,
        snapshot: SensorSnapshot?,
        weather: WeatherSnapshot?,
        now: Date = Date()
    ) -> OperatingMode {
        if state.heatingEnabled {
            return .heating
        }

        switch state.selection {
        case .summer:
            return .summer
        case .transition:
            return .transition
        case .automatic:
            return automaticMode(snapshot: snapshot, weather: weather, now: now)
        }
    }

    private static func automaticMode(
        snapshot: SensorSnapshot?,
        weather: WeatherSnapshot?,
        now: Date
    ) -> OperatingMode {
        if let indoorTemperature = snapshot?.indoor.temperature,
           indoorTemperature >= 23 {
            return .summer
        }

        let relevantWeather: [WeatherReading]
        if let weather,
           abs(now.timeIntervalSince(weather.timestamp)) <= 90 * 60 {
            let horizon = now.addingTimeInterval(6 * 60 * 60)
            relevantWeather = [weather.current] + weather.hourlyForecast.filter {
                $0.timestamp >= now && $0.timestamp <= horizon
            }
        } else {
            relevantWeather = []
        }

        if relevantWeather.map(\.temperature).max() ?? -Double.infinity >= 20 {
            return .summer
        }

        return .transition
    }
}
