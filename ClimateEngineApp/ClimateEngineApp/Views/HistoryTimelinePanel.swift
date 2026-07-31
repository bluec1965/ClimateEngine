import SwiftUI
import ClimateEngine

struct HistoryTimelinePanel: View {
    let events: [HistoryEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timeline heute")
                .font(.title3)
                .fontWeight(.semibold)

            if events.isEmpty {
                Text("Noch keine Ereignisse")
                    .foregroundStyle(.secondary)
            } else {

                let recentEvents = Array(events.suffix(5).reversed())

                ForEach(Array(recentEvents.enumerated()), id: \.offset) { index, event in

                    VStack(alignment: .leading, spacing: 10) {

                        HStack(alignment: .top, spacing: 12) {

                            Image(systemName: icon(for: event.recommendation))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(color(for: event.recommendation))
                                .frame(width: 24)

                            HStack(spacing: 6) {

                                Text(formatTime(event.timestamp))
                                    .font(.headline)
                                    .monospacedDigit()

                                Text(title(for: event.recommendation))
                                    .fontWeight(.semibold)

                            }
                        }

                        if index < recentEvents.count - 1 {

                            Divider()
                                .padding(.leading, 22)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .frame(width: 620, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
    private func icon(for recommendation: String) -> String {
        switch recommendation {
        case "ventilate":
            return "wind.circle.fill"
        case "closeWindows":
            return "xmark.circle.fill"
        default:
            return "minus.circle.fill"
        }
    }
}
