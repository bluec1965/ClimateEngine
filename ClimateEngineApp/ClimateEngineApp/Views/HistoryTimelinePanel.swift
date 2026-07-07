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
                ForEach(Array(events.suffix(5).reversed().enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(color(for: event.recommendation))
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(formatTime(event.timestamp)) · \(title(for: event.recommendation))")
                                .fontWeight(.semibold)

                            Text(event.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
}
