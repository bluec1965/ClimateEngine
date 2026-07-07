import SwiftUI
import ClimateEngine

struct RecommendationPanel: View {

    let analysis: VentilationAnalysis?

    var body: some View {

        VStack(spacing: 14) {

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

            if let analysis {

                HStack(spacing: 16) {

                    ComparisonBox(
                        title: "Temperaturvergleich",
                        indoor: String(format: "%.1f °C", analysis.indoorTemperature),
                        outdoor: String(format: "%.1f °C", analysis.outdoorTemperature),
                        difference: String(
                            format: "%+.1f °C",
                            analysis.outdoorTemperature - analysis.indoorTemperature
                        ),
                        differenceIsGood: analysis.outdoorTemperature < analysis.indoorTemperature
                    )

                    ComparisonBox(
                        title: "Feuchtigkeitsvergleich",
                        indoor: String(format: "%.1f g/m³", analysis.indoorAbsoluteHumidity),
                        outdoor: String(format: "%.1f g/m³", analysis.outdoorAbsoluteHumidity),
                        difference: String(
                            format: "%+.1f g/m³",
                            analysis.absoluteHumidityDifference
                        ),
                        differenceIsGood: analysis.outdoorAbsoluteHumidity < analysis.indoorAbsoluteHumidity
                    )
                }

                VStack(alignment: .leading, spacing: 8) {

                    Text("Voraussetzungen zum Lüften")
                        .font(.headline)

                    requirementRow(
                        "Aussenluft ist trockener",
                        fulfilled: analysis.outdoorAbsoluteHumidity < analysis.indoorAbsoluteHumidity
                    )

                    requirementRow(
                        "Aussenluft ist kühler",
                        fulfilled: analysis.outdoorTemperature < analysis.indoorTemperature
                    )
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }

    private var recommendation: VentilationRecommendation {
        analysis?.recommendation ?? .neutral
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
        analysis?.explanation ?? "Noch keine Analyse verfügbar."
    }

    @ViewBuilder
    private func requirementRow(
        _ text: String,
        fulfilled: Bool
    ) -> some View {

        Label {

            Text(text)

        } icon: {

            Image(
                systemName: fulfilled
                ? "checkmark.circle.fill"
                : "xmark.circle.fill"
            )
            .foregroundStyle(
                fulfilled
                ? .green
                : .red
            )
        }
    }
}
