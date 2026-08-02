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
        if arguments.first?.lowercased() == "weather" {
            return try WeatherConnectorCommand(paths: paths, now: now).run(
                standardInput: standardInput
            )
        }

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
            let readings = makeSensorReadings(from: numericValues)
            try SensorSnapshotWriter().write(
                indoorRooms: readings.indoorRooms,
                outdoorSensors: readings.outdoorSensors,
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
            explanation: analysis.explanation,
            indoorRooms: snapshot.indoorRooms,
            outdoorSensors: snapshot.outdoorSensors
        )
    }

    private func makeSensorReadings(
        from values: [Double]
    ) -> (indoorRooms: [SensorReading], outdoorSensors: [SensorReading]) {
        var indoorRooms = [
            reading(
                id: "stube",
                name: "Stube",
                temperature: values[0],
                humidity: values[1],
                isPrimary: true
            )
        ]
        var outdoorSensors = [
            reading(
                id: "eve-degree",
                name: "Eve Degree",
                temperature: values[2],
                humidity: values[3],
                isPrimary: true
            )
        ]

        guard values.count >= 12 else {
            return (indoorRooms, outdoorSensors)
        }

        let additionalIndoorRooms = [
            (id: "schlafzimmer", name: "Schlafzimmer", startIndex: 4),
            (id: "buero-alois", name: "Büro Alois", startIndex: 6),
            (id: "sauna", name: "Sauna", startIndex: 8)
        ]
        for room in additionalIndoorRooms {
            indoorRooms.append(
                reading(
                    id: room.id,
                    name: room.name,
                    temperature: values[room.startIndex],
                    humidity: values[room.startIndex + 1]
                )
            )
        }

        outdoorSensors.append(
            reading(
                id: "homepod-terrasse",
                name: "HomePod Terrasse",
                temperature: values[10],
                humidity: values[11]
            )
        )

        return (indoorRooms, outdoorSensors)
    }

    private func reading(
        id: String,
        name: String,
        temperature: Double,
        humidity: Double,
        isPrimary: Bool = false
    ) -> SensorReading {
        SensorReading(
            id: id,
            name: name,
            measurement: ClimateMeasurement(
                temperature: temperature,
                humidity: humidity
            ),
            isPrimary: isPrimary
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
