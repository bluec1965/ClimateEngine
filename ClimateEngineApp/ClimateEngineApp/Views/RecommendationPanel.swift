import SwiftUI
import ClimateEngine

struct RecommendationPanel: View {

    let analysis: VentilationAnalysis?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 15) {
                LiquidGlassStatusIcon(
                    status: status,
                    size: 52,
                    symbolSize: 22
                )

                VStack(alignment: .leading, spacing: 4) {
                    LiquidGlassSectionLabel(text: "SMS-Empfehlung · Stube")

                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)

                    Text(explanation)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }
            }

            if let analysis {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 270), spacing: 16)],
                    spacing: 16
                ) {
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
                        .foregroundStyle(.white)

                    requirementRow(
                        "Aussenluft ist trockener",
                        fulfilled: analysis.outdoorAbsoluteHumidity < analysis.indoorAbsoluteHumidity
                    )

                    requirementRow(
                        "Aussenluft ist kühler",
                        fulfilled: analysis.outdoorTemperature < analysis.indoorTemperature
                    )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassInset(cornerRadius: 18)
                .font(.caption)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(glowColor: color)
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

    private var status: LiquidGlassStatus {
        switch recommendation {
        case .ventilate:
            return .ventilate
        case .neutral:
            return .neutral
        case .closeWindows:
            return .close
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

        HStack(spacing: 10) {
            LiquidGlassIndicatorIcon(
                systemName: fulfilled ? "checkmark" : "xmark",
                tint: fulfilled ? .green : .red,
                size: 26,
                symbolSize: 10
            )

            Text(text)
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
    }
}
