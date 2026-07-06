import Foundation
import ClimateEngine

let home = FileManager.default.homeDirectoryForCurrentUser

let snapshotURL = home
    .appendingPathComponent("Library")
    .appendingPathComponent("Containers")
    .appendingPathComponent("io.github.bluec1965.ClimateEngineApp")
    .appendingPathComponent("Data")
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

do {
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
