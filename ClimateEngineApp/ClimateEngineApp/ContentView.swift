import SwiftUI
import Combine
import ClimateEngine

struct ContentView: View {
    @State private var snapshot: SensorSnapshot?
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
                    humidity: formatHumidity(snapshot?.indoor.humidity)
                )

                ClimateCard(
                    title: "Outdoor",
                    systemImage: "tree.fill",
                    temperature: formatTemperature(snapshot?.outdoor.temperature),
                    humidity: formatHumidity(snapshot?.outdoor.humidity)
                )
            }

            Divider()

            VStack(spacing: 8) {
                if snapshot == nil {
                    Label("Waiting for sensor data…", systemImage: "circle.dashed")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Sensor data loaded", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let lastUpdated {
                    Text("Last updated: \(lastUpdated.formatted(date: .omitted, time: .standard))")
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
        .frame(minWidth: 620, minHeight: 440)
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
            snapshot = try loader.load(from: snapshotURL)
            lastUpdated = Date()
            loadError = nil
        } catch {
            loadError = "Could not load sensor data"
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
}

private struct ClimateCard: View {
    let title: String
    let systemImage: String
    let temperature: String
    let humidity: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                ClimateRow(label: "Temperature", value: temperature)
                ClimateRow(label: "Humidity", value: humidity)
            }
        }
        .padding(20)
        .frame(width: 250, alignment: .leading)
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
