import Foundation

enum WeatherInputParserError: Error, CustomStringConvertible {
    case missingCurrentWeather
    case invalidLine(Int, String)
    case invalidNumber(Int, String)
    case invalidTimestamp(Int, String)
    case invalidHumidity(Int, Double)
    case invalidPrecipitationChance(Int, Double)

    var description: String {
        switch self {
        case .missingCurrentWeather:
            return "Im Wettertext fehlt eine CURRENT-Zeile."
        case .invalidLine(let line, let cause):
            return "Ungültige Wetterzeile \(line): \(cause)"
        case .invalidNumber(let line, let value):
            return "Ungültiger Zahlenwert in Wetterzeile \(line): \(value)"
        case .invalidTimestamp(let line, let value):
            return "Ungültiger Zeitpunkt in Wetterzeile \(line): \(value)"
        case .invalidHumidity(let line, let value):
            return "Luftfeuchtigkeit ausserhalb 0–100 % in Wetterzeile \(line): \(value)"
        case .invalidPrecipitationChance(let line, let value):
            return "Niederschlagswahrscheinlichkeit ausserhalb 0–100 % in Wetterzeile \(line): \(value)"
        }
    }
}

struct WeatherInputParser {
    func parse(_ input: String, now: Date) throws -> WeatherSnapshot {
        var location = "Aktueller Ort"
        var current: WeatherReading?
        var forecast: [WeatherReading] = []

        for (offset, rawLine) in input.components(separatedBy: .newlines).enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line != "CLIMATEENGINE_WEATHER_V1" else { continue }

            let fields = line
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            switch fields.first?.uppercased() {
            case "LOCATION":
                guard fields.count >= 2, !fields[1].isEmpty else {
                    throw WeatherInputParserError.invalidLine(
                        lineNumber,
                        "LOCATION benötigt einen Ortsnamen."
                    )
                }
                location = fields.dropFirst().joined(separator: "|")

            case "CURRENT":
                guard current == nil else {
                    throw WeatherInputParserError.invalidLine(
                        lineNumber,
                        "CURRENT darf nur einmal vorkommen."
                    )
                }
                current = try reading(from: fields, lineNumber: lineNumber, now: now)

            case "FORECAST":
                forecast.append(
                    try reading(from: fields, lineNumber: lineNumber, now: now)
                )

            default:
                throw WeatherInputParserError.invalidLine(
                    lineNumber,
                    "Erwartet werden LOCATION, CURRENT oder FORECAST."
                )
            }
        }

        guard let current else {
            throw WeatherInputParserError.missingCurrentWeather
        }

        return WeatherSnapshot(
            timestamp: now,
            location: location,
            current: current,
            hourlyForecast: forecast
        )
    }

    private func reading(
        from fields: [String],
        lineNumber: Int,
        now: Date
    ) throws -> WeatherReading {
        guard fields.count >= 7 else {
            throw WeatherInputParserError.invalidLine(
                lineNumber,
                "Benötigt werden Zeitpunkt, Temperatur, Feuchtigkeit, Wetterlage, Niederschlagswahrscheinlichkeit und Wind."
            )
        }

        let timestamp = try timestamp(from: fields[1], lineNumber: lineNumber, now: now)
        let temperature = try number(from: fields[2], lineNumber: lineNumber)
        var humidity = try number(from: fields[3], lineNumber: lineNumber)
        if humidity <= 1, !fields[3].contains("%") {
            humidity *= 100
        }
        guard (0...100).contains(humidity) else {
            throw WeatherInputParserError.invalidHumidity(lineNumber, humidity)
        }

        let condition = fields[4]
        guard !condition.isEmpty else {
            throw WeatherInputParserError.invalidLine(
                lineNumber,
                "Die Wetterlage darf nicht leer sein."
            )
        }

        let precipitationChance = try optionalPercentage(
            from: fields[5],
            lineNumber: lineNumber
        )
        let windSpeed = try optionalNumber(
            from: fields[6],
            lineNumber: lineNumber
        )
        let precipitationAmount = fields.count > 7
            ? try optionalNumber(from: fields[7], lineNumber: lineNumber)
            : nil

        return WeatherReading(
            timestamp: timestamp,
            temperature: temperature,
            humidity: humidity,
            condition: condition,
            precipitationChance: precipitationChance,
            windSpeed: windSpeed,
            precipitationAmount: precipitationAmount
        )
    }

    private func timestamp(
        from value: String,
        lineNumber: Int,
        now: Date
    ) throws -> Date {
        if value.uppercased() == "NOW" {
            return now
        }

        if value.hasPrefix("+"),
           let hourOffset = Int(value.dropFirst()),
           hourOffset > 0 {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let nextFullHour = calendar.dateInterval(of: .hour, for: now)?.end
                ?? now.addingTimeInterval(60 * 60)
            return calendar.date(
                byAdding: .hour,
                value: hourOffset - 1,
                to: nextFullHour
            ) ?? now.addingTimeInterval(Double(hourOffset) * 60 * 60)
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return date
        }
        isoFormatter.formatOptions.insert(.withFractionalSeconds)
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "de_CH")
        for format in ["yyyy-MM-dd HH:mm", "dd.MM.yyyy HH:mm", "dd.MM.yyyy, HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        throw WeatherInputParserError.invalidTimestamp(lineNumber, value)
    }

    private func optionalPercentage(
        from value: String,
        lineNumber: Int
    ) throws -> Double? {
        guard !value.isEmpty, value != "–", value != "-" else { return nil }
        var result = try number(from: value, lineNumber: lineNumber)
        if result <= 1, !value.contains("%") {
            result *= 100
        }
        guard (0...100).contains(result) else {
            throw WeatherInputParserError.invalidPrecipitationChance(lineNumber, result)
        }
        return result
    }

    private func optionalNumber(
        from value: String,
        lineNumber: Int
    ) throws -> Double? {
        guard !value.isEmpty, value != "–", value != "-" else { return nil }
        return try number(from: value, lineNumber: lineNumber)
    }

    private func number(from value: String, lineNumber: Int) throws -> Double {
        let pattern = #"[-+]?(?:\d+(?:[\.,]\d*)?|[\.,]\d+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              let range = Range(match.range, in: value),
              let result = Double(value[range].replacingOccurrences(of: ",", with: ".")) else {
            throw WeatherInputParserError.invalidNumber(lineNumber, value)
        }
        return result
    }
}
