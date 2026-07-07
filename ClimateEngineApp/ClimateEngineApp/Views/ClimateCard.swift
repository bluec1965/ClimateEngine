import SwiftUI

struct ClimateCard: View {
    let title: String
    let systemImage: String
    let temperature: String
    let humidity: String
    let dewPoint: String
    let absoluteHumidity: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                ClimateRow(label: "Temperatur", value: temperature)
                ClimateRow(label: "Luftfeuchtigkeit", value: humidity)
                ClimateRow(label: "Taupunkt", value: dewPoint)
                ClimateRow(label: "Absolute Luftfeuchtigkeit", value: absoluteHumidity)
            }
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
