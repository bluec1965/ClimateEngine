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

do {
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
        print("Jetzt können die Fenster geschlossen werden. Die Aussenluft ist nun wärmer und feuchter als die Raumluft.")
    }

} catch {
    print("Fehler beim Laden der Sensordaten.")
}
