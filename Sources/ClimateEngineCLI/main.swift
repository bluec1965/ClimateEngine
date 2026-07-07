import Foundation
import ClimateEngine

let snapshotURL = CLIPaths.snapshotURL
let historyDirectory = CLIPaths.historyDirectory

let notificationState = NotificationState()

func recommendationText(_ recommendation: VentilationRecommendation) -> String {
    switch recommendation {
    case .ventilate:
        return "ventilate"
    case .neutral:
        return "neutral"
    case .closeWindows:
        return "closeWindows"
    }
}

func historyEntry(
    from snapshot: SensorSnapshot,
    analysis: VentilationAnalysis,
    notificationSent: Bool
) -> HistoryEntry {
    HistoryEntry(
        timestamp: snapshot.timestamp,
        indoorTemperature: snapshot.indoor.temperature,
        indoorHumidity: snapshot.indoor.humidity,
        indoorAbsoluteHumidity: analysis.indoorAbsoluteHumidity,
        indoorDewPoint: ClimateCalculator.dewPoint(
            temperatureCelsius: snapshot.indoor.temperature,
            relativeHumidity: snapshot.indoor.humidity
        ),
        outdoorTemperature: snapshot.outdoor.temperature,
        outdoorHumidity: snapshot.outdoor.humidity,
        outdoorAbsoluteHumidity: analysis.outdoorAbsoluteHumidity,
        outdoorDewPoint: ClimateCalculator.dewPoint(
            temperatureCelsius: snapshot.outdoor.temperature,
            relativeHumidity: snapshot.outdoor.humidity
        ),
        recommendation: recommendationText(analysis.recommendation),
        notificationSent: notificationSent,
        explanation: analysis.explanation
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

    let snapshot = try SensorSnapshotLoader().load(from: snapshotURL)
    let analysis = VentilationAdvisor.analyze(snapshot: snapshot)

    var notificationSent = false

    if analysis.recommendation == .closeWindows,
       !notificationState.alreadyNotifiedToday() {

        print("Jetzt ist ein guter Zeitpunkt, die Nachtlüftung zu beenden. Die Fenster können geschlossen werden. Die Aussenluft ist inzwischen wärmer und feuchter als die Raumluft.")

        try notificationState.markNotifiedToday()
        notificationSent = true
    }

    let currentEntry = historyEntry(
        from: snapshot,
        analysis: analysis,
        notificationSent: notificationSent
    )

    let historyReader = HistoryReader(directory: historyDirectory)
    let previousEntry = try historyReader.loadToday().last

    let shouldStore = HistoryPolicy().shouldStore(
        previous: previousEntry,
        current: currentEntry
    )

    if shouldStore {
        try HistoryWriter(directory: historyDirectory).append(currentEntry)
    }

} catch {
    print("Fehler beim Laden der Sensordaten.")
}
