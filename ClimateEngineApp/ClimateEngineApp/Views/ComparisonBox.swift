import SwiftUI

struct ComparisonBox: View {
    let title: String
    let indoor: String
    let outdoor: String
    let difference: String
    let differenceIsGood: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LiquidGlassGlyph(
                    systemName: title == "Temperaturvergleich" ? "thermometer.medium" : "humidity.fill",
                    size: 32,
                    symbolSize: 20
                )

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            ClimateRow(label: "Innen", value: indoor)
            ClimateRow(label: "Aussen", value: outdoor)

            HStack {

                Text("Differenz")
                    .foregroundStyle(LiquidGlassTheme.secondaryText)

                Spacer()

                LiquidGlassIndicatorIcon(
                    systemName: differenceIsGood ? "arrow.down" : "arrow.up",
                    tint: differenceIsGood ? .green : .red,
                    size: 16,
                    symbolSize: 8,
                    vibrant: true
                )

                Text(difference)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(differenceIsGood ? .green : .red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
        .liquidGlassInset(cornerRadius: 18)
    }
}
