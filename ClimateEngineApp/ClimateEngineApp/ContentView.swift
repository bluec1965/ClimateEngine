import SwiftUI
import Combine
import ClimateEngine

struct ContentView: View {
    @State private var snapshot: SensorSnapshot?
    @State private var analysis: VentilationAnalysis?
    @State private var historySummary = HistorySummary(
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

    private let refreshTimer = Timer.publish(
        every: 10,
        on: .main,
        in: .common
    ).autoconnect()

    private let paths = ClimateEnginePaths.current

    var body: some View {
        ScrollView(.vertical) {
            dashboardContent
                .padding(32)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 760, minHeight: 740)
        .onAppear {
            loadSnapshot()
        }
        .onReceive(refreshTimer) { _ in
            loadSnapshot()
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Climate Engine")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Der intelligente Klima-Assistent")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Version 1.3-alpha")
                    .foregroundStyle(.secondary)
            }

            Divider()

            sensorSection(
                title: "Innenräume",
                subtitle: "Stube bleibt während der Beobachtungsphase die SMS-Referenz.",
                readings: snapshot?.indoorRooms ?? [],
                systemImage: "house.fill"
            )

            sensorSection(
                title: "Aussensensoren",
                subtitle: outdoorSensorSubtitle,
                readings: snapshot?.outdoorSensors ?? [],
                systemImage: "tree.fill"
            )

            if let snapshot {
                RoomObservationPanel(
                    rooms: snapshot.indoorRooms,
                    referenceOutdoor: snapshot.outdoor
                )
            }

            Divider()

            RecommendationPanel(analysis: analysis)

            Divider()

            HistorySummaryPanel(
                summary: historySummary,
                statistics: historyStatistics
            )

            HistoryTimelinePanel(events: historyEvents)
            Divider()

            VStack(spacing: 8) {
                if snapshot == nil {
                    Label("Warte auf Sensordaten…", systemImage: "circle.dashed")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Sensordaten geladen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let measurementTime = snapshot?.timestamp {
                    Text("Sensormessung: \(measurementTime.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .font(.headline)
        }
    }

    private func sensorSection(
        title: String,
        subtitle: String,
        readings: [SensorReading],
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        referenceLabel: reading.isPrimary ? "SMS-Referenz" : nil
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outdoorSensorSubtitle: String {
        guard let readings = snapshot?.outdoorSensors, readings.count > 1 else {
            return "Eve Degree bleibt während der Beobachtungsphase die SMS-Referenz."
        }
        let temperatures = readings.map(\.measurement.temperature)
        let spread = (temperatures.max() ?? 0) - (temperatures.min() ?? 0)
        return String(
            format: "Eve Degree ist SMS-Referenz · aktuelle Temperaturspanne %.1f °C",
            spread
        )
    }

    private func loadSnapshot() {
        do {
            let loadedSnapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
            let loadedAnalysis = VentilationAdvisor.analyze(snapshot: loadedSnapshot)

            snapshot = loadedSnapshot
            analysis = loadedAnalysis
            loadError = nil
        } catch {
            loadError = "Sensordaten konnten nicht geladen werden: \(error)"
        }

        do {
            let reader = HistoryReader(directory: paths.historyDirectory)
            let entries = try reader.loadToday()
            historySummary = try reader.todaySummary()
            historyEvents = try reader.todayEvents()
            historyStatistics = HistoryAnalyzer().statistics(from: entries)
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

private struct RoomObservationPanel: View {
    let rooms: [SensorReading]
    let referenceOutdoor: ClimateMeasurement

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Raumbeobachtung")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Noch ohne zusätzliche SMS-Benachrichtigungen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoomObservationRow: View {
    let room: SensorReading
    let analysis: VentilationAnalysis

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .fontWeight(.semibold)
                Text(analysis.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private var icon: String {
        switch analysis.recommendation {
        case .ventilate: return "wind"
        case .neutral: return "minus.circle.fill"
        case .closeWindows: return "xmark.circle.fill"
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
