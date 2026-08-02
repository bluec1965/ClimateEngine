import Foundation

public struct WeatherSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let source: String
    public let location: String
    public let current: WeatherReading
    public let hourlyForecast: [WeatherReading]

    public init(
        version: Int = 1,
        timestamp: Date,
        source: String = "Apple Weather via Shortcuts",
        location: String,
        current: WeatherReading,
        hourlyForecast: [WeatherReading]
    ) {
        self.version = version
        self.timestamp = timestamp
        self.source = source
        self.location = location
        self.current = current
        self.hourlyForecast = hourlyForecast.sorted { $0.timestamp < $1.timestamp }
    }
}

public struct WeatherReading: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let temperature: Double
    public let humidity: Double
    public let condition: String
    public let precipitationChance: Double?
    public let windSpeed: Double?
    public let precipitationAmount: Double?

    public init(
        timestamp: Date,
        temperature: Double,
        humidity: Double,
        condition: String,
        precipitationChance: Double? = nil,
        windSpeed: Double? = nil,
        precipitationAmount: Double? = nil
    ) {
        self.timestamp = timestamp
        self.temperature = temperature
        self.humidity = humidity
        self.condition = condition
        self.precipitationChance = precipitationChance
        self.windSpeed = windSpeed
        self.precipitationAmount = precipitationAmount
    }

    public var dewPoint: Double {
        ClimateCalculator.dewPoint(
            temperatureCelsius: temperature,
            relativeHumidity: humidity
        )
    }

    public var absoluteHumidity: Double {
        ClimateCalculator.absoluteHumidity(
            temperatureCelsius: temperature,
            relativeHumidity: humidity
        )
    }
}
