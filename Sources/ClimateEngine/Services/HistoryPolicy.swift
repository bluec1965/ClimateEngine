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

        if sensorReadingsChanged(previous.indoorRooms, current.indoorRooms) {
            return true
        }

        if sensorReadingsChanged(previous.outdoorSensors, current.outdoorSensors) {
            return true
        }

        return false
    }

    private func sensorReadingsChanged(
        _ previous: [SensorReading],
        _ current: [SensorReading]
    ) -> Bool {
        guard previous.map(\.id) == current.map(\.id) else {
            return true
        }

        return zip(previous, current).contains { old, new in
            let oldAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
                temperatureCelsius: old.measurement.temperature,
                relativeHumidity: old.measurement.humidity
            )
            let newAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
                temperatureCelsius: new.measurement.temperature,
                relativeHumidity: new.measurement.humidity
            )
            return abs(old.measurement.temperature - new.measurement.temperature) >= temperatureThreshold
                || abs(oldAbsoluteHumidity - newAbsoluteHumidity) >= absoluteHumidityThreshold
        }
    }
}
