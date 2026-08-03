import SwiftUI

struct ClimateCard: View {
    let title: String
    let systemImage: String
    let temperature: String
    let humidity: String
    let dewPoint: String
    let absoluteHumidity: String
    let referenceLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    LiquidGlassGlyph(
                        systemName: systemImage,
                        size: 42,
                        symbolSize: 27
                    )

                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

                Spacer()

                if let referenceLabel {
                    Text(referenceLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(LiquidGlassTheme.mint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlassInset(cornerRadius: 99)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ClimateRow(label: "Temperatur", value: temperature)
                ClimateRow(label: "Luftfeuchtigkeit", value: humidity)
                ClimateRow(label: "Taupunkt", value: dewPoint)
                ClimateRow(label: "Absolute Luftfeuchtigkeit", value: absoluteHumidity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 22, glowColor: LiquidGlassTheme.cyan)
    }
}
