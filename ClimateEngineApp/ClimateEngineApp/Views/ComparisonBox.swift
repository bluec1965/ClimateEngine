import SwiftUI

struct ComparisonBox: View {
    let title: String
    let indoor: String
    let outdoor: String
    let difference: String
    let differenceIsGood: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.headline)

            ClimateRow(label: "Innen", value: indoor)
            ClimateRow(label: "Aussen", value: outdoor)

            HStack {

                Text("Differenz")
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: differenceIsGood ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(differenceIsGood ? .green : .red)

                Text(difference)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(differenceIsGood ? .green : .red)
            }
        }
        .padding(14)
        .frame(width: 300, height: 145)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
