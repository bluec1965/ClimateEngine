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

                Text("Version 1.2-alpha")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                ClimateCard(
                    title: "Innen",
                    systemImage: "house.fill",
                    temperature: formatTemperature(snapshot?.indoor.temperature),
                    humidity: formatHumidity(snapshot?.indoor.humidity),
                    dewPoint: formatDewPoint(snapshot?.indoor),
                    absoluteHumidity: formatAbsoluteHumidity(snapshot?.indoor)
                )

                ClimateCard(
                    title: "Aussen",
                    systemImage: "tree.fill",
                    temperature: formatTemperature(snapshot?.outdoor.temperature),
                    humidity: formatHumidity(snapshot?.outdoor.humidity),
                    dewPoint: formatDewPoint(snapshot?.outdoor),
                    absoluteHumidity: formatAbsoluteHumidity(snapshot?.outdoor)
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

#Preview {
    ContentView()
}
