import SwiftUI
import ClimateEngine

struct HistoryTimelinePanel: View {
    let events: [HistoryEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                LiquidGlassGlyph(
                    systemName: "clock.arrow.circlepath",
                    size: 40,
                    symbolSize: 23
                )

                VStack(alignment: .leading, spacing: 3) {
                    LiquidGlassSectionLabel(text: "Verlauf")
                    Text("Timeline heute")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }

            if events.isEmpty {
                Text("Noch keine Ereignisse")
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
            } else {

                let recentEvents = Array(events.suffix(5).reversed())

                ForEach(Array(recentEvents.enumerated()), id: \.offset) { index, event in

                    VStack(alignment: .leading, spacing: 10) {

                        HStack(alignment: .top, spacing: 12) {

                            LiquidGlassStatusIcon(
                                status: status(for: event.recommendation),
                                size: 34,
                                symbolSize: 14
                            )

                            HStack(spacing: 6) {

                                Text(formatTime(event.timestamp))
                                    .font(.headline)
                                    .monospacedDigit()

                                Text(title(for: event.recommendation))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(LiquidGlassTheme.secondaryText)

                            }
                        }

                        if index < recentEvents.count - 1 {

                            Rectangle()
                                .fill(LiquidGlassTheme.divider)
                                .frame(height: 1)
                                .padding(.leading, 34)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 22, glowColor: LiquidGlassTheme.mint)
    }

    private func title(for recommendation: String) -> String {
        switch recommendation {
        case "ventilate":
            return "Jetzt lüften"
        case "closeWindows":
            return "Fenster geschlossen halten"
        default:
            return "Keine Empfehlung"
        }
    }

    private func color(for recommendation: String) -> Color {
        switch recommendation {
        case "ventilate":
            return .green
        case "closeWindows":
            return .red
        default:
            return .orange
        }
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
    private func status(for recommendation: String) -> LiquidGlassStatus {
        switch recommendation {
        case "ventilate":
            return .ventilate
        case "closeWindows":
            return .close
        default:
            return .neutral
        }
    }
}
