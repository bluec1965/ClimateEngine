import SwiftUI

struct ClimateRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(LiquidGlassTheme.secondaryText)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
