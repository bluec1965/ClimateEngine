import SwiftUI
import ClimateEngine

struct HistorySummaryPanel: View {
    let summary: HistorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Historie heute")
                .font(.title3)
                .fontWeight(.semibold)

            ClimateRow(label: "Messungen", value: "\(summary.measurementCount)")
            ClimateRow(label: "Erste Messung", value: formatTime(summary.firstMeasurement))
            ClimateRow(label: "Letzte Messung", value: formatTime(summary.lastMeasurement))
        }
        .padding(20)
        .frame(width: 620, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
