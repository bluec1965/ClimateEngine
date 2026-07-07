import Foundation

public struct HistoryPolicy {

    public let temperatureThreshold: Double
    public let absoluteHumidityThreshold: Double
    public let heartbeatInterval: TimeInterval

    public init(
        temperatureThreshold: Double = 0.2,
        absoluteHumidityThreshold: Double = 0.2,
        heartbeatInterval: TimeInterval = 10 * 60
    ) {
        self.temperatureThreshold = temperatureThreshold
        self.absoluteHumidityThreshold = absoluteHumidityThreshold
        self.heartbeatInterval = heartbeatInterval
    }

    public func shouldStore(
        previous: HistoryEntry?,
        current: HistoryEntry
    ) -> Bool {

        guard let previous else {
            return true
        }

        if previous.recommendation != current.recommendation {
            return true
        }

        if abs(current.timestamp.timeIntervalSince(previous.timestamp)) >= heartbeatInterval {
            return true
        }

        if abs(current.indoorTemperature - previous.indoorTemperature) >= temperatureThreshold {
            return true
        }

        if abs(current.outdoorTemperature - previous.outdoorTemperature) >= temperatureThreshold {
            return true
        }

        if abs(current.indoorAbsoluteHumidity - previous.indoorAbsoluteHumidity) >= absoluteHumidityThreshold {
            return true
        }

        if abs(current.outdoorAbsoluteHumidity - previous.outdoorAbsoluteHumidity) >= absoluteHumidityThreshold {
            return true
        }

        return false
    }
}
