import Foundation
import ClimateEngine

let snapshotURL = CLIPaths.snapshotURL
let historyDirectory = CLIPaths.historyDirectory

let windowStateStore = WindowStateStore(
    fileURL: CLIPaths.windowStateURL
)

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

func speechText(for action: NotificationAction) -> String? {
    switch action {
    case .openWindows:
        return "Die Aussenluft ist jetzt kühler und trockener als die Raumluft. Es ist ein guter Zeitpunkt, die Fenster zu öffnen."

    case .closeWindows:
        return "Die Aussenluft ist nicht mehr optimal. Bitte die Fenster jetzt schliessen."

    case .none:
        return nil
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

    var numericValues = arguments.compactMap {
        try? MeasurementParser.double(from: $0)
    }

    // Falls keine Argumente vorhanden sind,
    // versuchen wir vier Zeilen von stdin zu lesen.
    if numericValues.count < 4 {

        let stdin = String(
            data: FileHandle.standardInput.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        let lines = stdin
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        numericValues = lines.compactMap {
            try? MeasurementParser.double(from: $0)
        }
    }

    if numericValues.count >= 4 {

        let indoorTemperature = numericValues[0]
        let indoorHumidity = numericValues[1]
        let outdoorTemperature = numericValues[2]
        let outdoorHumidity = numericValues[3]

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

    let currentState = try windowStateStore.load()

    let notification = NotificationManager().evaluate(
        recommendation: analysis.recommendation,
        state: currentState
    )

    var notificationSent = false

    switch notification.action {

    case .openWindows:
        print("OPEN_WINDOWS")
        notificationSent = true

    case .closeWindows:
        print("CLOSE_WINDOWS")
        notificationSent = true

    case .none:
        print("NONE")
    }

    if notification.newState != currentState {
        try windowStateStore.save(notification.newState)
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
