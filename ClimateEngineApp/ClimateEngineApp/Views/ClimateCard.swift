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
                Label(title, systemImage: systemImage)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if let referenceLabel {
                    Text(referenceLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12))
                        .clipShape(Capsule())
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
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
