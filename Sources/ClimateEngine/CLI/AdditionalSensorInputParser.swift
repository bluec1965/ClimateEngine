import Foundation

enum AdditionalSensorInputError: Error, CustomStringConvertible {
    case invalidValueCount(expected: Int, actual: Int)
    case invalidValue(position: Int, value: String)
    case invalidTemperature(sensor: String, value: Double)
    case invalidHumidity(sensor: String, value: Double)

    var description: String {
        switch self {
        case .invalidValueCount(let expected, let actual):
            return "Der Additional Sensor Connector muss genau \(expected) Werte liefern; empfangen wurden \(actual)."
        case .invalidValue(let position, let value):
            return "Zusatzsensorwert \(position) ist keine gültige Zahl: \(value)"
        case .invalidTemperature(let sensor, let value):
            return "Unplausible Temperatur für \(sensor): \(value) °C"
        case .invalidHumidity(let sensor, let value):
            return "Unplausible Luftfeuchtigkeit für \(sensor): \(value) %"
        }
    }
}

struct AdditionalSensorInputParser {
    struct Definition {
        let id: String
        let name: String
        let roomID: String
        let roomName: String
    }

    static let definitions = [
        Definition(id: "homepod-kueche", name: "HomePod Küche", roomID: "stube", roomName: "Stube"),
        Definition(id: "homepod-bad-peter", name: "HomePod Bad Peter", roomID: "bad-peter", roomName: "Bad Peter"),
        Definition(id: "homepod-schlafzimmer", name: "HomePod Schlafzimmer", roomID: "schlafzimmer", roomName: "Schlafzimmer"),
        Definition(id: "homepod-buero-alois-rechts", name: "HomePod Büro Alois Rechts", roomID: "buero-alois", roomName: "Büro Alois"),
        Definition(id: "homepod-sauna-links", name: "HomePod Sauna Links", roomID: "sauna", roomName: "Sauna"),
        Definition(id: "homepod-buero-peter", name: "HomePod Büro Peter", roomID: "buero-peter", roomName: "Büro Peter"),
        Definition(id: "homepod-bad-alois", name: "HomePod Bad Alois", roomID: "bad-alois", roomName: "Bad Alois"),
        Definition(id: "dachzimmer-sensor", name: "Dachzimmer", roomID: "dachzimmer", roomName: "Dachzimmer")
    ]

    func parse(_ input: String, now: Date) throws -> AdditionalSensorSnapshot {
        let definitions = Self.definitions
        let lines = input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "CLIMATEENGINE_ADDITIONAL_SENSORS_V1" }

        let expectedCount = definitions.count * 2
        guard lines.count == expectedCount else {
            throw AdditionalSensorInputError.invalidValueCount(
                expected: expectedCount,
                actual: lines.count
            )
        }

        var sensors: [AdditionalSensorReading] = []
        for (index, definition) in definitions.enumerated() {
            let temperature = try number(from: lines[index * 2], position: index * 2 + 1)
            var humidity = try number(from: lines[index * 2 + 1], position: index * 2 + 2)
            if humidity <= 1, !lines[index * 2 + 1].contains("%") {
                humidity *= 100
            }

            guard (-20...50).contains(temperature) else {
                throw AdditionalSensorInputError.invalidTemperature(
                    sensor: definition.name,
                    value: temperature
                )
            }
            guard (0...100).contains(humidity) else {
                throw AdditionalSensorInputError.invalidHumidity(
                    sensor: definition.name,
                    value: humidity
                )
            }

            sensors.append(
                AdditionalSensorReading(
                    id: definition.id,
                    name: definition.name,
                    roomID: definition.roomID,
                    roomName: definition.roomName,
                    measurement: ClimateMeasurement(
                        temperature: temperature,
                        humidity: humidity
                    )
                )
            )
        }

        return AdditionalSensorSnapshot(timestamp: now, sensors: sensors)
    }

    private func number(from value: String, position: Int) throws -> Double {
        let pattern = #"[-+]?(?:\d+(?:[\.,]\d*)?|[\.,]\d+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              let range = Range(match.range, in: value),
              let result = Double(value[range].replacingOccurrences(of: ",", with: ".")) else {
            throw AdditionalSensorInputError.invalidValue(
                position: position,
                value: value
            )
        }
        return result
    }
}
