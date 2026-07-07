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
    @State private var lastUpdated: Date?
    @State private var loadError: String?

    private let refreshTimer = Timer.publish(
        every: 10,
        on: .main,
        in: .common
    ).autoconnect()

    private var snapshotURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/ClimateEngine/current.json")
    }

    private var historyDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/ClimateEngine/history")
    }

    var body: some View {
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

            HistorySummaryPanel(summary: historySummary)

            Divider()

            VStack(spacing: 8) {
                if snapshot == nil {
                    Label("Warte auf Sensordaten…", systemImage: "circle.dashed")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Sensordaten geladen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let lastUpdated {
                    Text("Letzte Aktualisierung: \(lastUpdated.formatted(date: .omitted, time: .standard))")
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
        .padding(32)
        .frame(minWidth: 760, minHeight: 740)
        .onAppear {
            loadSnapshot()
        }
        .onReceive(refreshTimer) { _ in
            loadSnapshot()
        }
    }

    private func loadSnapshot() {
        do {
            let loader = SensorSnapshotLoader()
            let loadedSnapshot = try loader.load(from: snapshotURL)
            let loadedAnalysis = VentilationAdvisor.analyze(snapshot: loadedSnapshot)

            snapshot = loadedSnapshot
            analysis = loadedAnalysis
            historySummary = try HistoryReader(directory: historyDirectory).todaySummary()
            lastUpdated = Date()
            loadError = nil
        } catch {
            loadError = "Sensordaten konnten nicht geladen werden."
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
