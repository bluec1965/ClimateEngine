import Foundation
import ClimateEngine

let home = FileManager.default.homeDirectoryForCurrentUser

let snapshotURL = home
    .appendingPathComponent("Documents")
    .appendingPathComponent("ClimateEngine")
    .appendingPathComponent("current.json")

let stateDirectory = home
    .appendingPathComponent("Library")
    .appendingPathComponent("Application Support")
    .appendingPathComponent("ClimateEngine")

let stateURL = stateDirectory
    .appendingPathComponent("last-summer-night-ventilation-notification.txt")

func todayKey() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "de_CH")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

func alreadyNotifiedToday() -> Bool {
    guard let content = try? String(contentsOf: stateURL, encoding: .utf8) else {
        return false
    }

    return content.trimmingCharacters(in: .whitespacesAndNewlines) == todayKey()
}

func markNotifiedToday() throws {
    try FileManager.default.createDirectory(
        at: stateDirectory,
        withIntermediateDirectories: true
    )

    try todayKey().write(
        to: stateURL,
        atomically: true,
        encoding: .utf8
    )
}

func numericValue(from text: String) throws -> Double {
    let cleaned = text
        .replacingOccurrences(of: ",", with: ".")
        .filter { character in
            character.isNumber || character == "." || character == "-"
        }

    guard let value = Double(cleaned) else {
        throw NSError(domain: "ClimateEngineCLI", code: 1)
    }

    return value
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())

    if arguments.count == 4 {
        let indoorTemperature = try numericValue(from: arguments[0])
        let indoorHumidity = try numericValue(from: arguments[1])
        let outdoorTemperature = try numericValue(from: arguments[2])
        let outdoorHumidity = try numericValue(from: arguments[3])

        try SensorSnapshotWriter().write(
            indoorTemperature: indoorTemperature,
            indoorHumidity: indoorHumidity,
            outdoorTemperature: outdoorTemperature,
            outdoorHumidity: outdoorHumidity,
            to: snapshotURL
        )
    }

    if alreadyNotifiedToday() {
        exit(0)
    }

    let snapshot = try SensorSnapshotLoader().load(from: snapshotURL)

    let indoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
        temperatureCelsius: snapshot.indoor.temperature,
        relativeHumidity: snapshot.indoor.humidity
    )

    let outdoorAbsoluteHumidity = ClimateCalculator.absoluteHumidity(
        temperatureCelsius: snapshot.outdoor.temperature,
        relativeHumidity: snapshot.outdoor.humidity
    )

    let outdoorIsWarmerOrEqual = snapshot.outdoor.temperature >= snapshot.indoor.temperature
    let outdoorIsMoreHumidOrEqual = outdoorAbsoluteHumidity >= indoorAbsoluteHumidity

    if outdoorIsWarmerOrEqual && outdoorIsMoreHumidOrEqual {
        print("Jetzt ist ein guter Zeitpunkt, die Nachtlüftung zu beenden. Die Fenster können geschlossen werden. Die Aussenluft ist inzwischen wärmer und feuchter als die Raumluft.")
        try markNotifiedToday()
    }

} catch {
    print("Fehler beim Laden der Sensordaten.")
}
