import Foundation
import ClimateEngine

let home = FileManager.default.homeDirectoryForCurrentUser

let snapshotURL =
home
    .appendingPathComponent("Library")
    .appendingPathComponent("Containers")
    .appendingPathComponent("io.github.bluec1965.ClimateEngineApp")
    .appendingPathComponent("Data")
    .appendingPathComponent("Documents")
    .appendingPathComponent("ClimateEngine")
    .appendingPathComponent("current.json")

do {

    let loader = SensorSnapshotLoader()

    let snapshot = try loader.load(from: snapshotURL)

    let recommendation = VentilationAdvisor.recommendation(for: snapshot)

    switch recommendation {

    case .ventilate:

        print("Jetzt lüften.")

    case .closeWindows:

        print("Fenster geschlossen halten.")

    case .neutral:

        print("Keine Lüftungsempfehlung.")
    }

} catch {

    print("Fehler beim Laden der Sensordaten.")
}
