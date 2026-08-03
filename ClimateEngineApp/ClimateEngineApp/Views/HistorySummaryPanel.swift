import SwiftUI
import ClimateEngine

struct HistorySummaryPanel: View {
    let summary: HistorySummary
    let statistics: HistoryStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                LiquidGlassGlyph(
                    systemName: "chart.xyaxis.line",
                    size: 40,
                    symbolSize: 23
                )

                VStack(alignment: .leading, spacing: 3) {
                    LiquidGlassSectionLabel(text: "Heute")
                    Text("Historie")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }

            ClimateRow(label: "Messungen", value: "\(statistics.measurementCount)")
            ClimateRow(label: "Empfehlungswechsel", value: "\(statistics.recommendationChanges)")
            ClimateRow(label: "Lüftungsfenster", value: "\(statistics.ventilationPeriods)")
            ClimateRow(label: "Erste Messung", value: formatTime(summary.firstMeasurement))
            ClimateRow(label: "Letzte Messung", value: formatTime(summary.lastMeasurement))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 22, glowColor: LiquidGlassTheme.cyan)
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
