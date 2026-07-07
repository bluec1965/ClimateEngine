import Foundation
import ClimateEngine

let snapshotURL = CLIPaths.snapshotURL
let stateDirectory = CLIPaths.stateDirectory
let stateURL = CLIPaths.stateURL

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
    let arguments = Array(CommandLine.arguments.dropFirst())

    if arguments.count == 4 {
        let indoorTemperature = try MeasurementParser.double(from: arguments[0])
        let indoorHumidity = try MeasurementParser.double(from: arguments[1])
        let outdoorTemperature = try MeasurementParser.double(from: arguments[2])
        let outdoorHumidity = try MeasurementParser.double(from: arguments[3])

        try SensorSnapshotWriter().write(
            indoorTemperature: indoorTemperature,
            indoorHumidity: indoorHumidity,
            outdoorTemperature: outdoorTemperature,
            outdoorHumidity: outdoorHumidity,
            to: snapshotURL
        )
    }

    let notificationState = NotificationState()

    if notificationState.alreadyNotifiedToday(){
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
        try notificationState.markNotifiedToday()
    }

} catch {
    print("Fehler beim Laden der Sensordaten.")
}
