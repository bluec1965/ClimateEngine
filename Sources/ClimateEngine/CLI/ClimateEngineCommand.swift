import Foundation

public struct ClimateEngineCommand {
    public let paths: ClimateEnginePaths
    public let now: () -> Date

    public init(
        paths: ClimateEnginePaths = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.paths = paths
        self.now = now
    }

    @discardableResult
    public func run(arguments: [String], standardInput: String = "") throws -> String {
        let executionDate = now()
        var numericValues = arguments.compactMap {
            try? MeasurementParser.double(from: $0)
        }

        if numericValues.count < 4 {
            numericValues = standardInput
                .split(whereSeparator: \.isNewline)
                .compactMap { try? MeasurementParser.double(from: String($0)) }
        }

        if numericValues.count >= 4 {
            try SensorSnapshotWriter().write(
                indoorTemperature: numericValues[0],
                indoorHumidity: numericValues[1],
                outdoorTemperature: numericValues[2],
                outdoorHumidity: numericValues[3],
                timestamp: executionDate,
                to: paths.snapshotURL
            )
        }

        let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
        let analysis = VentilationAdvisor.analyze(snapshot: snapshot)
        let stateStore = WindowStateStore(fileURL: paths.windowStateURL)
        let currentState = try stateStore.load(now: executionDate)
        let notification = NotificationManager().evaluate(
            recommendation: analysis.recommendation,
            state: currentState,
            now: executionDate
        )

        if notification.newState != currentState {
            try stateStore.save(notification.newState, now: executionDate)
        }

        let entry = makeHistoryEntry(
            snapshot: snapshot,
            analysis: analysis,
            notificationSent: notification.action != .none
        )
        let reader = HistoryReader(directory: paths.historyDirectory)
        if HistoryPolicy().shouldStore(
            previous: try reader.loadToday(now: snapshot.timestamp).last,
            current: entry
        ) {
            try HistoryWriter(directory: paths.historyDirectory).append(entry)
        }

        switch notification.action {
        case .openWindows: return "OPEN_WINDOWS"
        case .closeWindows: return "CLOSE_WINDOWS"
        case .none: return "NONE"
        }
    }

    private func makeHistoryEntry(
        snapshot: SensorSnapshot,
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

    private func recommendationText(_ recommendation: VentilationRecommendation) -> String {
        switch recommendation {
        case .ventilate: return "ventilate"
        case .neutral: return "neutral"
        case .closeWindows: return "closeWindows"
        }
    }
}
