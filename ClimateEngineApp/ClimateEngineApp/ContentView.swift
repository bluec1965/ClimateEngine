import SwiftUI
import Combine
import AppKit
import ClimateEngine

struct ContentView: View {
    @State private var snapshot: SensorSnapshot?
    @State private var analysis: VentilationAnalysis?
    @State private var acquisitionStatus: SensorAcquisitionStatus?
    @State private var acquisitionLoadError: String?
    @State private var historySummary = HistorySummary(
        measurementCount: 0,
        firstMeasurement: nil,
        lastMeasurement: nil
    )
    @State private var additionalHistorySummary = HistorySummary(
        measurementCount: 0,
        firstMeasurement: nil,
        lastMeasurement: nil
    )
    @State private var loadError: String?
    @State private var historyStatistics = HistoryStatistics(
        measurementCount: 0,
        recommendationChanges: 0,
        ventilationPeriods: 0
    )
    @State private var historyEvents: [HistoryEvent] = []
    @State private var historyLoadError: String?
    @State private var weatherSnapshot: WeatherSnapshot?
    @State private var weatherLoadError: String?
    @State private var additionalSensorSnapshot: AdditionalSensorSnapshot?
    @State private var additionalAcquisitionStatus: SensorAcquisitionStatus?
    @State private var additionalSensorLoadError: String?
    @State private var additionalSensorHistoryLoadError: String?
    @State private var operatingModeState = OperatingModeState.defaultState()
    @State private var seasonalRecommendation: SeasonalRecommendationSnapshot?
    @State private var operatingModeLoadError: String?

    private let refreshTimer = Timer.publish(
        every: 10,
        on: .main,
        in: .common
    ).autoconnect()

    private let paths = ClimateEnginePaths.current

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView(.vertical) {
                dashboardContent
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 1040)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 760, minHeight: 740)
        .preferredColorScheme(.dark)
        .onAppear {
            loadSnapshot()
        }
        .onReceive(refreshTimer) { _ in
            loadSnapshot()
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 26) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionLabel(text: "Live vom Mac mini")

                    Text("Climate Engine")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(LiquidGlassTheme.brandGradient)
                        .shadow(color: LiquidGlassTheme.cyan.opacity(0.22), radius: 16)

                    Text("Der intelligente Klima-Assistent")
                        .font(.title3)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)

                    Text("Version 1.4-alpha")
                        .font(.caption)
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                HeaderRecommendationBadge(analysis: analysis)
                    .frame(width: 220)

                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                    .shadow(color: Color.black.opacity(0.42), radius: 22, y: 14)
                    .shadow(color: LiquidGlassTheme.cyan.opacity(0.18), radius: 18, y: 3)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            OperatingModePanel(
                state: operatingModeState,
                effectiveMode: OperatingModeResolver.resolve(
                    state: operatingModeState,
                    snapshot: snapshot,
                    weather: weatherSnapshot
                ),
                shadowRecommendation: measurementUnavailableReason == nil ? seasonalRecommendation : nil,
                errorMessage: operatingModeLoadError,
                onHeatingChanged: updateHeatingState,
                onSelectionChanged: updateOperatingModeSelection
            )

            indoorRoomSection

            if let message = measurementUnavailableReason ?? acquisitionStatus?.outdoorSummary {
                Label(message, systemImage: measurementUnavailableReason == nil
                    ? "antenna.radiowaves.left.and.right" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(measurementUnavailableReason != nil
                        || !(acquisitionStatus?.unavailableOutdoorIDs.isEmpty ?? true)
                        ? Color.orange : LiquidGlassTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .liquidGlassCard(cornerRadius: 18, glowColor: .orange, raised: false)
            }

            sensorSection(
                title: "Aussensensoren",
                subtitle: outdoorSensorSubtitle,
                readings: snapshot?.outdoorSensors ?? [],
                systemImage: "tree.fill"
            )

            WeatherObservationPanel(
                snapshot: weatherSnapshot,
                loadError: weatherLoadError
            )

            if let snapshot, measurementUnavailableReason == nil {
                RoomObservationPanel(
                    rooms: snapshot.indoorRooms,
                    referenceOutdoor: StableVentilationAdvisor.outdoorMean(
                        from: snapshot.outdoorSensors
                    )
                )
            }

            RecommendationPanel(analysis: analysis)

            HistorySummaryPanel(
                summary: historySummary,
                statistics: historyStatistics,
                additionalSummary: additionalHistorySummary
            )

            HistoryTimelinePanel(events: historyEvents)
            LiquidGlassDivider()

            VStack(spacing: 8) {
                if snapshot == nil {
                    Label("Warte auf Sensordaten…", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                } else {
                    HStack(spacing: 10) {
                        LiquidGlassIndicatorIcon(
                            systemName: measurementUnavailableReason == nil ? "checkmark" : "exclamationmark",
                            tint: measurementUnavailableReason == nil ? .green : .orange,
                            size: 26,
                            symbolSize: 10,
                            vibrant: true
                        )

                        Text(measurementUnavailableReason == nil
                            ? "Sensordaten geladen" : "Letzte erfolgreiche Sensormessung")
                            .foregroundStyle(measurementUnavailableReason == nil
                                ? LiquidGlassTheme.mint : .orange)
                    }
                }

                if let measurementTime = snapshot?.timestamp {
                    Text("Sensormessung: \(measurementTime.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                if let measurementTime = additionalSensorSnapshot?.timestamp {
                    Text("Zusatzsensoren: \(measurementTime.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let historyLoadError {
                    Text(historyLoadError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let additionalSensorLoadError {
                    Text(additionalSensorLoadError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let additionalSensorHistoryLoadError {
                    Text(additionalSensorHistoryLoadError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .liquidGlassCard(cornerRadius: 18, glowColor: LiquidGlassTheme.mint, raised: false)
        }
    }

    private var indoorRoomSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                LiquidGlassSectionLabel(text: "Innen")

                Text("Innenräume")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(indoorRoomSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                if let warning = additionalSensorSnapshot?.availabilityMessage(status: additionalAcquisitionStatus)
                    ?? (additionalAcquisitionStatus?.accepted == false ? additionalAcquisitionStatus?.message : nil) {
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 430), spacing: 20)],
                spacing: 20
            ) {
                ForEach(indoorRoomGroups) { room in
                    RoomSensorGroupCard(room: room)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var indoorRoomGroups: [RoomSensorGroup] {
        RoomSensorGrouper().groups(
            primaryRooms: snapshot?.indoorRooms ?? [],
            additionalSensors: additionalSensorSnapshot?.currentSensors(status: additionalAcquisitionStatus) ?? [],
            includeBiasCorrectedMeasurements: sensorSnapshotsAreAligned
        )
    }

    private var indoorRoomSubtitle: String {
        let explanation: String
        if additionalSensorSnapshot == nil || sensorSnapshotsAreAligned {
            explanation = "Bias-Korrektur nur mit zwei aktuellen Sensoren; Büro Alois und Sauna vorläufig."
        } else {
            explanation = "Bias-korrigierte Raumwerte warten auf zeitlich passende Haupt- und Zusatzmessungen."
        }
        guard let timestamp = additionalSensorSnapshot?.timestamp else {
            return explanation
        }

        return "\(explanation) · Zusatzmessung \(timestamp.formatted(date: .omitted, time: .shortened))"
    }

    private var sensorSnapshotsAreAligned: Bool {
        guard let primaryTimestamp = snapshot?.timestamp,
              let additionalTimestamp = additionalSensorSnapshot?.timestamp else {
            return false
        }

        return abs(primaryTimestamp.timeIntervalSince(additionalTimestamp)) <= 3 * 60
    }

    private func sensorSection(
        title: String,
        subtitle: String,
        readings: [SensorReading],
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                LiquidGlassSectionLabel(text: "Aussen")

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 290), spacing: 20)],
                spacing: 20
            ) {
                ForEach(readings) { reading in
                    ClimateCard(
                        title: reading.name,
                        systemImage: systemImage,
                        temperature: formatTemperature(reading.measurement.temperature),
                        humidity: formatHumidity(reading.measurement.humidity),
                        dewPoint: formatDewPoint(reading.measurement),
                        absoluteHumidity: formatAbsoluteHumidity(reading.measurement),
                        referenceLabel: title == "Innenräume" && reading.isPrimary
                            ? "SMS-Referenz"
                            : nil
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outdoorSensorSubtitle: String {
        if measurementUnavailableReason != nil {
            return "Zuletzt verfügbare Messwerte · aktuell keine neue Empfehlung."
        }
        if let status = acquisitionStatus ?? snapshot?.acquisition {
            return status.outdoorSummary
        }
        guard let readings = snapshot?.outdoorSensors, readings.count > 1 else {
            return "Der vorhandene Aussensensor wird für die Empfehlung verwendet."
        }
        let temperatures = readings.map(\.measurement.temperature)
        let spread = (temperatures.max() ?? 0) - (temperatures.min() ?? 0)
        return String(
            format: "Aussenmittel aus %d Sensoren · aktuelle Temperaturspanne %.1f °C",
            readings.count,
            spread
        )
    }

    private func loadSnapshot() {
        do {
            acquisitionStatus = try SensorAcquisitionStore().load(from: paths.sensorAcquisitionURL)
            acquisitionLoadError = nil
        } catch {
            acquisitionStatus = nil
            acquisitionLoadError = "Sensorstatus konnte nicht gelesen werden · keine aktuelle Empfehlung."
        }
        do {
            let loadedSnapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
            let loadedAnalysis = (try? RecommendationSnapshotStore().load(
                from: paths.recommendationSnapshotURL
            ))?.analysis ?? VentilationAdvisor.analyze(
                indoor: loadedSnapshot.indoor,
                outdoor: StableVentilationAdvisor.outdoorMean(
                    from: loadedSnapshot.outdoorSensors
                )
            )

            snapshot = loadedSnapshot
            analysis = acquisitionLoadError == nil && SensorAcquisitionStatus.unavailableReason(
                snapshot: loadedSnapshot, status: acquisitionStatus
            ) == nil ? loadedAnalysis : nil
            loadError = nil
        } catch {
            analysis = nil
            loadError = "Sensordaten konnten nicht geladen werden: \(error)"
        }

        do {
            additionalAcquisitionStatus = try SensorAcquisitionStore().load(from: paths.additionalSensorAcquisitionURL)
            additionalSensorSnapshot = try AdditionalSensorSnapshotStore().load(
                from: paths.additionalSensorSnapshotURL
            )
            additionalSensorLoadError = nil
        } catch let error as AdditionalSensorSnapshotStoreError {
            additionalSensorSnapshot = nil
            switch error {
            case .fileNotFound:
                additionalSensorLoadError = "Noch keine Zusatzsensordaten verfügbar."
            default:
                additionalSensorLoadError = error.description
            }
        } catch {
            additionalSensorSnapshot = nil
            additionalSensorLoadError = String(describing: error)
        }

        do {
            let reader = HistoryReader(directory: paths.historyDirectory)
            let result = try reader.loadTodayWithDiagnostics()
            let entries = result.entries
            historySummary = reader.summary(from: entries)
            historyEvents = reader.events(from: entries)
            historyStatistics = HistoryAnalyzer().statistics(from: entries)
            if result.skippedLineCount > 0 {
                historyLoadError = "Historie teilweise geladen: \(result.skippedLineCount) beschädigte Einträge wurden ignoriert."
            } else {
                historyLoadError = nil
            }
        } catch {
            historySummary = HistorySummary(
                measurementCount: 0,
                firstMeasurement: nil,
                lastMeasurement: nil
            )
            historyEvents = []
            historyStatistics = HistoryStatistics(
                measurementCount: 0,
                recommendationChanges: 0,
                ventilationPeriods: 0
            )
            historyLoadError = "Historie konnte nicht geladen werden: \(error)"
        }

        do {
            let reader = AdditionalSensorHistoryReader(
                directory: paths.additionalSensorHistoryDirectory
            )
            let result = try reader.loadTodayWithDiagnostics()
            additionalHistorySummary = reader.summary(from: result.timestamps)
            if result.skippedLineCount > 0 {
                additionalSensorHistoryLoadError = "Zusatzhistorie teilweise geladen: \(result.skippedLineCount) beschädigte Einträge wurden ignoriert."
            } else {
                additionalSensorHistoryLoadError = nil
            }
        } catch {
            additionalHistorySummary = HistorySummary(
                measurementCount: 0,
                firstMeasurement: nil,
                lastMeasurement: nil
            )
            additionalSensorHistoryLoadError = "Zusatzhistorie konnte nicht geladen werden: \(error)"
        }

        do {
            weatherSnapshot = try WeatherSnapshotStore().load(
                from: paths.weatherSnapshotURL
            )
            weatherLoadError = nil
        } catch let error as WeatherSnapshotStoreError {
            weatherSnapshot = nil
            switch error {
            case .fileNotFound:
                weatherLoadError = nil
            default:
                weatherLoadError = error.description
            }
        } catch {
            weatherSnapshot = nil
            weatherLoadError = String(describing: error)
        }

        do {
            operatingModeState = try OperatingModeStore().load(
                from: paths.operatingModeURL
            )
            operatingModeLoadError = nil
        } catch {
            operatingModeState = .defaultState()
            operatingModeLoadError = "Betriebsart konnte nicht geladen werden: \(error)"
        }

        if FileManager.default.fileExists(
            atPath: paths.seasonalRecommendationSnapshotURL.path
        ) {
            do {
                seasonalRecommendation = try SeasonalRecommendationStore().load(
                    from: paths.seasonalRecommendationSnapshotURL
                )
            } catch {
                seasonalRecommendation = nil
                operatingModeLoadError = "Schattenauswertung konnte nicht geladen werden: \(error)"
            }
        } else {
            seasonalRecommendation = nil
        }
    }

    private var measurementUnavailableReason: String? {
        acquisitionLoadError ?? SensorAcquisitionStatus.unavailableReason(snapshot: snapshot, status: acquisitionStatus)
    }

    private func updateHeatingState(_ isEnabled: Bool) {
        saveOperatingMode(
            OperatingModeState(
                heatingEnabled: isEnabled,
                selection: isEnabled ? operatingModeState.selection : .automatic,
                updatedAt: Date()
            )
        )
    }

    private func updateOperatingModeSelection(_ selection: OperatingModeSelection) {
        guard !operatingModeState.heatingEnabled else { return }
        saveOperatingMode(
            OperatingModeState(
                heatingEnabled: false,
                selection: selection,
                updatedAt: Date()
            )
        )
    }

    private func saveOperatingMode(_ state: OperatingModeState) {
        do {
            try OperatingModeStore().write(state, to: paths.operatingModeURL)
            operatingModeState = state
            operatingModeLoadError = nil
        } catch {
            operatingModeLoadError = "Betriebsart konnte nicht gespeichert werden: \(error)"
        }
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "--.- °C" }
        return String(format: "%.1f °C", value)
    }

    private func formatHumidity(_ value: Double?) -> String {
        guard let value else { return "-- %" }
        return String(format: "%.0f %%", value)
    }

    private func formatDewPoint(_ measurement: ClimateMeasurement?) -> String {
        guard let measurement else { return "--.- °C" }

        let dewPoint = ClimateCalculator.dewPoint(
            temperatureCelsius: measurement.temperature,
            relativeHumidity: measurement.humidity
        )

        return String(format: "%.1f °C", dewPoint)
    }

    private func formatAbsoluteHumidity(_ measurement: ClimateMeasurement?) -> String {
        guard let measurement else { return "--.- g/m³" }

        let absoluteHumidity = ClimateCalculator.absoluteHumidity(
            temperatureCelsius: measurement.temperature,
            relativeHumidity: measurement.humidity
        )

        return String(format: "%.1f g/m³", absoluteHumidity)
    }
}

private struct WeatherObservationPanel: View {
    let snapshot: WeatherSnapshot?
    let loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    LiquidGlassSectionLabel(text: "Apple Weather")

                    Text("Wetterbeobachtung")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Apple Weather · Prognose für stabile Empfehlungen und Lüftungshinweise")
                        .font(.subheadline)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                Spacer()

                if let snapshot {
                    Text(freshnessText(snapshot.timestamp))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isStale(snapshot.timestamp) ? .orange : .green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlassInset(cornerRadius: 99)
                }
            }

            if let snapshot {
                currentWeather(snapshot)

                if !snapshot.hourlyForecast.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(
                            Array(snapshot.hourlyForecast.prefix(6).enumerated()),
                            id: \.offset
                        ) { index, reading in
                            WeatherForecastRow(reading: reading)
                            if index < min(snapshot.hourlyForecast.count, 6) - 1 {
                                Rectangle()
                                    .fill(LiquidGlassTheme.divider)
                                    .frame(height: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .liquidGlassInset(cornerRadius: 18)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        LiquidGlassIcon(
                            systemName: "cloud.sun.fill",
                            tint: LiquidGlassTheme.cyan,
                            size: 38,
                            symbolSize: 16
                        )
                        Text("Noch keine Wetterdaten")
                            .font(.headline)
                    }
                    Text(loadError ?? "Der separate Weather Connector wurde noch nicht ausgeführt.")
                        .font(.caption)
                        .foregroundColor(loadError == nil ? LiquidGlassTheme.secondaryText : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .liquidGlassInset(cornerRadius: 18)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(glowColor: LiquidGlassTheme.cyan)
    }

    private func currentWeather(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 12) {
                    LiquidGlassGlyph(
                        systemName: "location.fill",
                        size: 38,
                        symbolSize: 23
                    )

                    Text(snapshot.location)
                        .font(.headline)
                }
                Spacer()
                Text(snapshot.current.condition)
                    .fontWeight(.semibold)
                    .foregroundStyle(LiquidGlassTheme.ice)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 125), spacing: 14)],
                spacing: 14
            ) {
                WeatherMetric(title: "Temperatur", value: temperature(snapshot.current.temperature))
                WeatherMetric(title: "Luftfeuchte", value: percentage(snapshot.current.humidity))
                WeatherMetric(title: "Taupunkt", value: temperature(snapshot.current.dewPoint))
                WeatherMetric(title: "Absolute Feuchte", value: String(format: "%.1f g/m³", snapshot.current.absoluteHumidity))
                WeatherMetric(title: "Regenchance", value: optionalPercentage(snapshot.current.precipitationChance))
                WeatherMetric(title: "Wind", value: optionalSpeed(snapshot.current.windSpeed))
            }
        }
        .padding(18)
        .liquidGlassInset(cornerRadius: 18)
    }

    private func freshnessText(_ timestamp: Date) -> String {
        if isStale(timestamp) {
            return "Abruf veraltet · \(timestamp.formatted(date: .omitted, time: .shortened))"
        }
        return "Aktuell · \(timestamp.formatted(date: .omitted, time: .shortened))"
    }

    private func isStale(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) > 90 * 60
    }

    private func temperature(_ value: Double) -> String {
        String(format: "%.1f °C", value)
    }

    private func percentage(_ value: Double) -> String {
        String(format: "%.0f %%", value)
    }

    private func optionalPercentage(_ value: Double?) -> String {
        guard let value else { return "–" }
        return percentage(value)
    }

    private func optionalSpeed(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.1f km/h", value)
    }
}

private struct WeatherMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WeatherForecastRow: View {
    let reading: WeatherReading

    var body: some View {
        HStack(spacing: 14) {
            Text(reading.timestamp.formatted(date: .omitted, time: .shortened))
                .fontWeight(.semibold)
                .frame(width: 52, alignment: .leading)

            Text(reading.condition)
                .foregroundStyle(LiquidGlassTheme.secondaryText)
                .lineLimit(1)

            Spacer()

            Text(String(format: "%.1f °C", reading.temperature))
                .fontWeight(.semibold)
            Text(String(format: "%.1f g/m³", reading.absoluteHumidity))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
                .frame(width: 80, alignment: .trailing)
            Text(precipitationText)
                .foregroundColor(
                    (reading.precipitationChance ?? 0) >= 40
                    ? LiquidGlassTheme.cyan
                    : LiquidGlassTheme.secondaryText
                )
                .frame(width: 48, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
    }

    private var precipitationText: String {
        guard let chance = reading.precipitationChance else { return "–" }
        return String(format: "%.0f %%", chance)
    }
}

private struct HeaderRecommendationBadge: View {
    let analysis: VentilationAnalysis?

    var body: some View {
        HStack(spacing: 11) {
            LiquidGlassStatusIcon(
                status: status,
                size: 38,
                symbolSize: 15
            )

            VStack(alignment: .leading, spacing: 3) {
                LiquidGlassSectionLabel(text: "Aktuelle Empfehlung")

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassInset(cornerRadius: 18)
    }

    private var recommendation: VentilationRecommendation {
        analysis?.recommendation ?? .neutral
    }

    private var title: String {
        guard analysis != nil else { return "Warte auf Analyse" }

        switch recommendation {
        case .ventilate: return "Jetzt lüften"
        case .neutral: return "Keine Empfehlung"
        case .closeWindows: return "Fenster geschlossen halten"
        }
    }

    private var status: LiquidGlassStatus {
        switch recommendation {
        case .ventilate: return .ventilate
        case .neutral: return .neutral
        case .closeWindows: return .close
        }
    }

    private var color: Color {
        guard analysis != nil else { return LiquidGlassTheme.secondaryText }

        switch recommendation {
        case .ventilate: return .green
        case .neutral: return .orange
        case .closeWindows: return .red
        }
    }
}

private struct RoomObservationPanel: View {
    let rooms: [SensorReading]
    let referenceOutdoor: ClimateMeasurement

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                LiquidGlassSectionLabel(text: "Beobachtungsphase")

                Text("Raumbeobachtung")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Noch ohne zusätzliche SMS-Benachrichtigungen")
                    .font(.subheadline)
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
            }

            VStack(spacing: 0) {
                ForEach(rooms) { room in
                    RoomObservationRow(
                        room: room,
                        analysis: VentilationAdvisor.analyze(
                            indoor: room.measurement,
                            outdoor: referenceOutdoor
                        )
                    )

                    if room.id != rooms.last?.id {
                        Rectangle()
                            .fill(LiquidGlassTheme.divider)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .liquidGlassInset(cornerRadius: 18)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(glowColor: LiquidGlassTheme.mint)
    }
}

private struct RoomObservationRow: View {
    let room: SensorReading
    let analysis: VentilationAnalysis

    var body: some View {
        HStack(spacing: 14) {
            LiquidGlassStatusIcon(
                status: status,
                size: 34,
                symbolSize: 14
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(analysis.explanation)
                    .font(.caption)
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
            }

            Spacer()

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.vertical, 14)
    }

    private var title: String {
        switch analysis.recommendation {
        case .ventilate: return "Lüften"
        case .neutral: return "Beobachten"
        case .closeWindows: return "Geschlossen"
        }
    }

    private var status: LiquidGlassStatus {
        switch analysis.recommendation {
        case .ventilate: return .ventilate
        case .neutral: return .neutral
        case .closeWindows: return .close
        }
    }

    private var color: Color {
        switch analysis.recommendation {
        case .ventilate: return .green
        case .neutral: return .orange
        case .closeWindows: return .red
        }
    }
}

#Preview {
    ContentView()
}
