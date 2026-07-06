import SwiftUI
import Combine
import ClimateEngine

struct ContentView: View {
    @State private var snapshot: SensorSnapshot?
    @State private var recommendation: VentilationRecommendation = .neutral
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

    private var moistureDifference: Double? {
        guard let snapshot else { return nil }

        let analysis = VentilationAdvisor.analyze(snapshot: snapshot)
        return analysis.absoluteHumidityDifference
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Climate Engine")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version 0.2.0-alpha")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                ClimateCard(
                    title: "Indoor",
                    systemImage: "house.fill",
                    temperature: formatTemperature(snapshot?.indoor.temperature),
                    humidity: formatHumidity(snapshot?.indoor.humidity),
                    dewPoint: formatDewPoint(snapshot?.indoor),
                    absoluteHumidity: formatAbsoluteHumidity(snapshot?.indoor)
                )

                ClimateCard(
                    title: "Outdoor",
                    systemImage: "tree.fill",
                    temperature: formatTemperature(snapshot?.outdoor.temperature),
                    humidity: formatHumidity(snapshot?.outdoor.humidity),
                    dewPoint: formatDewPoint(snapshot?.outdoor),
                    absoluteHumidity: formatAbsoluteHumidity(snapshot?.outdoor)
                )
            }

            Divider()

            RecommendationPanel(
                recommendation: recommendation,
                moistureDifference: moistureDifference
            )

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
        .frame(minWidth: 720, minHeight: 580)
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
            let analysis = VentilationAdvisor.analyze(snapshot: loadedSnapshot)

            snapshot = loadedSnapshot
            recommendation = analysis.recommendation
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

private struct RecommendationPanel: View {
    let recommendation: VentilationRecommendation
    let moistureDifference: Double?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            Text(explanation)
                .foregroundStyle(.secondary)

            if let moistureDifference {
                Text(String(format: "Feuchtigkeitsdifferenz: %.1f g/m³", moistureDifference))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var title: String {
        switch recommendation {
        case .ventilate:
            return "Jetzt lüften"
        case .neutral:
            return "Keine Empfehlung"
        case .closeWindows:
            return "Fenster geschlossen halten"
        }
    }

    private var color: Color {
        switch recommendation {
        case .ventilate:
            return .green
        case .neutral:
            return .orange
        case .closeWindows:
            return .red
        }
    }

    private var explanation: String {
        switch recommendation {
        case .ventilate:
            return "Die Aussenluft enthält weniger Feuchtigkeit als die Raumluft."
        case .neutral:
            return "Innen- und Aussenluft unterscheiden sich nur gering."
        case .closeWindows:
            return "Die Aussenluft enthält mehr Feuchtigkeit als die Raumluft."
        }
    }
}

private struct ClimateCard: View {
    let title: String
    let systemImage: String
    let temperature: String
    let humidity: String
    let dewPoint: String
    let absoluteHumidity: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                ClimateRow(label: "Temperatur", value: temperature)
                ClimateRow(label: "Feuchtigkeit", value: humidity)
                ClimateRow(label: "Taupunkt", value: dewPoint)
                ClimateRow(label: "absol. Feuchtigkeit", value: absoluteHumidity)
            }
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct ClimateRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

#Preview {
    ContentView()
}
