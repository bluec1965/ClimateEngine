import SwiftUI
import ClimateEngine

struct RoomSensorGroupCard: View {
    let room: RoomSensorGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                LiquidGlassGlyph(
                    systemName: "house.fill",
                    size: 42,
                    symbolSize: 25
                )

                Text(room.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                if room.sensors.count > 1 {
                    badge("\(room.sensors.count) Sensoren", color: LiquidGlassTheme.cyan)
                }

                if room.isSMSReferenceRoom {
                    badge("SMS-Referenz", color: LiquidGlassTheme.mint)
                }
            }

            ForEach(Array(room.sensors.enumerated()), id: \.element.id) { index, sensor in
                sensorPanel(sensor, index: index)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 22, glowColor: LiquidGlassTheme.cyan)
    }

    private func sensorPanel(
        _ sensor: RoomSensorObservation,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(sensorTitle(sensor, index: index))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Text(sensor.origin == .mainConnector ? "Hauptmessung" : "Zusatzmessung")
                    .font(.caption2)
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
            }

            ClimateRow(
                label: "Temperatur",
                value: String(format: "%.1f °C", sensor.measurement.temperature)
            )
            ClimateRow(
                label: "Luftfeuchtigkeit",
                value: String(format: "%.0f %%", sensor.measurement.humidity)
            )
            ClimateRow(
                label: "Taupunkt",
                value: String(
                    format: "%.1f °C",
                    ClimateCalculator.dewPoint(
                        temperatureCelsius: sensor.measurement.temperature,
                        relativeHumidity: sensor.measurement.humidity
                    )
                )
            )
            ClimateRow(
                label: "Absolute Luftfeuchtigkeit",
                value: String(
                    format: "%.1f g/m³",
                    ClimateCalculator.absoluteHumidity(
                        temperatureCelsius: sensor.measurement.temperature,
                        relativeHumidity: sensor.measurement.humidity
                    )
                )
            )
        }
        .padding(15)
        .liquidGlassInset(cornerRadius: 17)
    }

    private func sensorTitle(
        _ sensor: RoomSensorObservation,
        index: Int
    ) -> String {
        guard room.sensors.count > 1 else { return sensor.name }
        return "Sensor \(index + 1) · \(sensor.name)"
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .liquidGlassInset(cornerRadius: 99)
    }
}
