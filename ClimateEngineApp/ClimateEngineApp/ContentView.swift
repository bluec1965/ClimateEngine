import SwiftUI
import ClimateEngine

struct ContentView: View {
    @State private var snapshot: SensorSnapshot?

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

            if snapshot == nil {
                Label("Waiting for sensor data…", systemImage: "circle.dashed")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Label("Sensor data loaded", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
        .padding(32)
        .frame(minWidth: 620, minHeight: 420)
        .onAppear {
            loadSnapshot()
        }
    }

    private func loadSnapshot() {
        let url = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/ClimateEngine/current.json")

        do {
            let loader = SensorSnapshotLoader()
            snapshot = try loader.load(from: url)
        } catch {
            print("Could not load sensor snapshot:", error)
            snapshot = nil
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
