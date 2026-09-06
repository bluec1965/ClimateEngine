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
        if arguments.first == "additional-readings" {
            return try AdditionalSensorConnectorCommand(paths: paths, now: now).runCollected(standardInput)
        }
        if arguments.first?.lowercased() == "additional-sensors" {
            return try AdditionalSensorConnectorCommand(paths: paths, now: now).run(
                standardInput: standardInput
            )
        }

        if arguments.first?.lowercased() == "weather" {
            return try WeatherConnectorCommand(paths: paths, now: now).run(
                standardInput: standardInput
            )
        }

        let executionDate = now()
        let collection: SensorCollection?
        if arguments.first == "sensor-readings" {
            do {
                collection = try SensorCollection.decode(standardInput, now: executionDate)
            } catch {
                try SensorAcquisitionStore().write(
                    SensorAcquisitionStatus(
                        timestamp: executionDate, accepted: false,
                        message: "Sensorlauf ungültig · keine aktuelle Lüftungsempfehlung.",
                        sensors: []
                    ),
                    to: paths.sensorAcquisitionURL
                )
                throw error
            }
        } else {
            collection = nil
        }
        var outdoorSourceChanged = false
        var numericValues = arguments.compactMap {
            try? MeasurementParser.double(from: $0)
        }

        if numericValues.count < 4 {
            numericValues = standardInput
                .split(whereSeparator: \.isNewline)
                .compactMap { try? MeasurementParser.double(from: String($0)) }
        }

        if numericValues.count >= 4 || collection != nil {
            let readings = collection.map { ($0.indoorRooms, $0.outdoorSensors) }
                ?? makeSensorReadings(from: numericValues)
            let indoorRooms = readings.0
            let outdoorSensors = readings.1
            let previousSnapshot: SensorSnapshot?
            if FileManager.default.fileExists(atPath: paths.snapshotURL.path) {
                previousSnapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
            } else {
                previousSnapshot = nil
            }
            if let collection {
                if let previousSnapshot, collection.timestamp <= previousSnapshot.timestamp {
                    // Replayed or out-of-order input must not produce another
                    // history entry, transition, notification or source change.
                    return "NONE"
                }
                let missingIndoor = collection.sensors.filter {
                    !SensorAcquisitionStatus.outdoorIDs.contains($0.id) && $0.measurement == nil
                }
                if !missingIndoor.isEmpty || outdoorSensors.isEmpty {
                    let message = outdoorSensors.isEmpty
                        ? "Beide Aussensensoren nicht verfügbar · keine aktuelle Lüftungsempfehlung."
                        : "Innenmessung unvollständig: " + missingIndoor.map(\.name).joined(separator: ", ")
                            + " · keine aktuelle Lüftungsempfehlung."
                    try SensorAcquisitionStore().write(
                        collection.status(at: executionDate, accepted: false, message: message),
                        to: paths.sensorAcquisitionURL
                    )
                    return "NONE"
                }
            }
            outdoorSourceChanged = previousSnapshot.map {
                Set($0.outdoorSensors.map(\.id)) != Set(outdoorSensors.map(\.id))
            } ?? false
            let qualityDecision = try SensorInputQualityController(
                stateURL: paths.sensorInputStateURL
            ).evaluate(
                indoorRooms: indoorRooms,
                outdoorSensors: outdoorSensors,
                previousSnapshot: previousSnapshot,
                now: executionDate,
                reportedUnavailableOutdoorIDs: collection.map {
                    $0.status(at: executionDate, accepted: false, message: "").unavailableOutdoorIDs
                } ?? []
            )
            try SensorInputAuditWriter(
                directory: paths.sensorInputHistoryDirectory
            ).append(
                SensorInputAuditEntry(
                    timestamp: executionDate,
                    accepted: qualityDecision.isAccepted,
                    reason: qualityDecision.reason,
                    indoorRooms: indoorRooms,
                    outdoorSensors: outdoorSensors
                )
            )
            guard qualityDecision.isAccepted else {
                if let collection {
                    try SensorAcquisitionStore().write(
                        collection.status(
                            at: executionDate, accepted: false, message: qualityDecision.reason
                        ), to: paths.sensorAcquisitionURL
                    )
                }
                switch qualityDecision.rejectionKind {
                case .incompleteSensorSet:
                    throw SensorInputValidationError.incompleteSensorSet(
                        qualityDecision.reason
                    )
                case .awaitingConfirmation, .none:
                    throw SensorInputValidationError.awaitingConfirmation(
                        qualityDecision.reason
                    )
                }
            }
            let acquisition = collection?.status(
                at: executionDate, accepted: true, message: "Aktuelle Messung akzeptiert."
            )
            try SensorSnapshotWriter().write(
                indoorRooms: indoorRooms,
                outdoorSensors: outdoorSensors,
                timestamp: collection?.timestamp ?? executionDate,
                acquisition: acquisition,
                to: paths.snapshotURL
            )
            if let acquisition {
                try SensorAcquisitionStore().write(acquisition, to: paths.sensorAcquisitionURL)
            }
        }

        let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
        if SensorAcquisitionStatus.unavailableReason(
            snapshot: snapshot,
            status: try SensorAcquisitionStore().load(from: paths.sensorAcquisitionURL),
            now: executionDate
        ) != nil {
            return "NONE"
        }
        let stateStore = WindowStateStore(fileURL: paths.windowStateURL)
        let currentState = try stateStore.load(now: executionDate)
        let recommendationStore = RecommendationSnapshotStore()
        var previousRecommendationState = try recommendationStore.loadState(
            from: paths.recommendationStateURL
        )
        if previousRecommendationState == nil {
            previousRecommendationState = RecommendationStabilityState(
                samples: [],
                effectiveRecommendation: currentState == .waitingForClosing
                    ? .ventilate
                    : .neutral
            )
        }
        if outdoorSourceChanged, let previous = previousRecommendationState {
            previousRecommendationState = RecommendationStabilityState(
                samples: [],
                effectiveRecommendation: previous.effectiveRecommendation,
                notifiedWeatherAdvisory: previous.notifiedWeatherAdvisory
            )
        }
        let weatherSnapshot = try? WeatherSnapshotStore().load(
            from: paths.weatherSnapshotURL
        )
        let stableResult = StableVentilationAdvisor().evaluate(
            snapshot: snapshot,
            weather: weatherSnapshot,
            previousState: previousRecommendationState,
            now: executionDate
        )
        try recommendationStore.write(
            stableResult.state,
            to: paths.recommendationStateURL
        )
        try recommendationStore.write(
            stableResult.snapshot,
            to: paths.recommendationSnapshotURL
        )
        let analysis = stableResult.snapshot.analysis
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

        persistSeasonalShadow(
            snapshot: snapshot,
            weather: weatherSnapshot,
            productionAnalysis: analysis,
            executionDate: executionDate
        )

        switch notification.action {
        case .openWindows:
            return outputToken(advisory: stableResult.snapshot.weatherAdvisory)
        case .closeWindows: return "CLOSE_WINDOWS"
        case .none:
            if currentState == .waitingForClosing,
               stableResult.weatherAdvisoryChanged {
                return outputToken(advisory: stableResult.snapshot.weatherAdvisory)
            }
            return "NONE"
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
            outdoorTemperature: analysis.outdoorTemperature,
            outdoorHumidity: ClimateCalculator.relativeHumidity(
                temperatureCelsius: analysis.outdoorTemperature,
                absoluteHumidity: analysis.outdoorAbsoluteHumidity
            ),
            outdoorAbsoluteHumidity: analysis.outdoorAbsoluteHumidity,
            outdoorDewPoint: ClimateCalculator.dewPoint(
                temperatureCelsius: analysis.outdoorTemperature,
                relativeHumidity: ClimateCalculator.relativeHumidity(
                    temperatureCelsius: analysis.outdoorTemperature,
                    absoluteHumidity: analysis.outdoorAbsoluteHumidity
                )
            ),
            recommendation: recommendationText(analysis.recommendation),
            notificationSent: notificationSent,
            explanation: analysis.explanation,
            indoorRooms: snapshot.indoorRooms,
            outdoorSensors: snapshot.outdoorSensors,
            acquisition: snapshot.acquisition
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

    private func outputToken(advisory: WeatherAdvisory?) -> String {
        switch advisory?.kind {
        case .rain: return "OPEN_WITH_RAIN_WARNING"
        case .wind: return "OPEN_WITH_WIND_WARNING"
        case .rainAndWind: return "OPEN_WITH_RAIN_AND_WIND_WARNING"
        case nil: return "OPEN_WINDOWS"
        }
    }

    /// The seasonal strategy remains observational in this rollout. Its state
    /// and history must never prevent the proven production recommendation or
    /// its existing Shortcuts output token from completing.
    private func persistSeasonalShadow(
        snapshot: SensorSnapshot,
        weather: WeatherSnapshot?,
        productionAnalysis: VentilationAnalysis,
        executionDate: Date
    ) {
        let operatingState = (try? OperatingModeStore().load(
            from: paths.operatingModeURL,
            now: executionDate
        )) ?? .defaultState(now: executionDate)
        let seasonalSnapshot = SeasonalVentilationAdvisor().evaluate(
            snapshot: snapshot,
            weather: weather,
            operatingState: operatingState,
            productionAnalysis: productionAnalysis,
            now: executionDate
        )

        do {
            try SeasonalRecommendationStore().write(
                seasonalSnapshot,
                to: paths.seasonalRecommendationSnapshotURL
            )
            if abs(snapshot.timestamp.timeIntervalSince(executionDate)) < 1 {
                try SeasonalRecommendationHistoryWriter(
                    directory: paths.seasonalRecommendationHistoryDirectory
                ).append(seasonalSnapshot)
            }
        } catch {
            // Deliberately non-fatal while the strategy runs in shadow mode.
        }
    }
}
