import SwiftUI
import ClimateEngine

struct RoomSensorGroupCard: View {
    let roomID: String
    let roomName: String
    let expectedThermostatCount: Int
    let room: RoomSensorGroup?
    let thermostatSnapshots: [HeatingThermostatSnapshot]
    let heatingEnabled: Bool
    let heatingControl: HeatingVentilationControl?
    let windowOpen: Bool
    let onWindowOpenChanged: ((Bool) -> Void)?
    let comfortActive: Bool
    let comfortRequestInFlight: Bool
    let onComfortChanged: ((Bool) -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(roomName) \(isExpanded ? "zuklappen" : "aufklappen")")

            if isExpanded {
                Divider()
                    .overlay(Color.white.opacity(0.10))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 15) {
                    sensorDetails
                    thermostatDetails
                    roomControls
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(
            cornerRadius: 19,
            glowColor: windowOpen ? .orange : summaryTint,
            raised: isExpanded
        )
    }

    private var summary: some View {
        HStack(spacing: 13) {
            LiquidGlassIndicatorIcon(
                systemName: room == nil ? "house" : "house.fill",
                tint: summaryTint,
                size: 34,
                symbolSize: 14,
                vibrant: windowOpen
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(roomName)
                    .font(.headline)
                    .foregroundStyle(LiquidGlassTheme.primaryText)
            }

            Spacer(minLength: 10)

            summaryMetric(
                icon: "thermometer.medium",
                primary: temperatureText,
                secondary: room?.biasCorrectedMeasurement == nil ? "Raumtemperatur" : "Bias-korrigiert"
            )

            summaryMetric(
                icon: "heater.vertical",
                primary: thermostatSummary,
                secondary: "Thermostate"
            )

            Text(targetSummary)
                .font(.caption)
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
                .lineLimit(2)
                .frame(minWidth: 110, alignment: .leading)

            if windowOpen {
                Label(roomID == "galerie" ? "Terrassentür offen" : "Fenster offen", systemImage: "window.vertical.open")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }

            if comfortActive {
                Label("Behaglichkeit", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LiquidGlassTheme.mint)
            }

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func summaryMetric(icon: String, primary: String, secondary: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(summaryTint)
            VStack(alignment: .leading, spacing: 1) {
                Text(primary)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                Text(secondary)
                    .font(.caption2)
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
            }
        }
        .frame(minWidth: 120, alignment: .leading)
    }

    @ViewBuilder
    private var sensorDetails: some View {
        detailHeading("Sensoren und Bias", icon: "sensor.fill")
        if let room {
            if let combined = room.biasCorrectedMeasurement {
                biasCorrectedPanel(combined)
                Text("Unveränderte Rohwerte")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
            }
            ForEach(Array(room.sensors.enumerated()), id: \.element.id) { index, sensor in
                sensorPanel(sensor, index: index, sensorCount: room.sensors.count)
            }
        } else {
            placeholder("Noch keine Sensoren verbunden.")
        }
    }

    @ViewBuilder
    private var thermostatDetails: some View {
        detailHeading("Thermostate", icon: "thermometer.medium")
        if thermostatSnapshots.isEmpty {
            placeholder("\(expectedThermostatCount) \(expectedThermostatCount == 1 ? "Thermostat ist" : "Thermostate sind") vorgesehen, aber noch nicht verbunden.")
        } else {
            ForEach(Array(thermostatSnapshots.enumerated()), id: \.offset) { _, snapshot in
                thermostatPanel(snapshot)
            }
            let missing = max(0, expectedThermostatCount - thermostatSnapshots.count)
            if missing > 0 {
                Text("Weitere \(missing) \(missing == 1 ? "Thermostat" : "Thermostate") vorgesehen")
                    .font(.caption)
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
            }
        }

        if ["schlafzimmer", "buero-peter", "buero-alois", "bad-alois", "sauna", "galerie", "dachzimmer"].contains(roomID) {
            let evaluation = HeatingWeeklySchedule.bueroAloisPrototype.evaluation()
            HStack {
                Label("Heizplan", systemImage: "calendar.badge.clock")
                    .foregroundStyle(LiquidGlassTheme.cyan)
                Spacer()
                Text(windowOpen
                    ? "Fenster offen · Heizung ausgeschaltet"
                    : "\(evaluation.period == .comfort ? "Komfort" : "Nacht") · Soll \(String(format: "%.1f °C", evaluation.targetTemperature))")
                    .foregroundStyle(windowOpen ? Color.orange : LiquidGlassTheme.secondaryText)
            }
            .font(.caption.weight(.semibold))
            .padding(12)
            .liquidGlassInset(cornerRadius: 14)
        }
    }

    private var roomControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailHeading("Raumfunktionen", icon: "slider.horizontal.3")
            HStack(spacing: 16) {
                if let onWindowOpenChanged {
                    Toggle(
                        roomID == "galerie" ? "Terrassentür offen" : "Fenster offen",
                        isOn: Binding(get: { windowOpen }, set: onWindowOpenChanged)
                    )
                    .toggleStyle(.switch)
                    .tint(.orange)
                } else {
                    Label("Fenstersteuerung folgt", systemImage: "window.vertical.closed")
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }

                Spacer()

                if let onComfortChanged {
                    Toggle(
                        comfortActive ? "Behaglichkeit · 24 °C" : "Behaglichkeit",
                        isOn: Binding(get: { comfortActive }, set: onComfortChanged)
                    )
                    .toggleStyle(.switch)
                    .tint(LiquidGlassTheme.mint)
                    .disabled(comfortRequestInFlight)
                } else {
                    Label(
                        roomID == "sauna" ? "Sauna-Behaglichkeit folgt" : "Raum-Behaglichkeit folgt",
                        systemImage: "sparkles"
                    )
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
            }
            .font(.caption.weight(.semibold))
        }
    }

    private func detailHeading(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(LiquidGlassTheme.primaryText)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(LiquidGlassTheme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .liquidGlassInset(cornerRadius: 14)
    }

    private func thermostatPanel(_ snapshot: HeatingThermostatSnapshot) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(thermostatTint(snapshot).opacity(0.85))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.roomName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                Text(thermostatStatus(snapshot))
                    .font(.caption)
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
            }
            Spacer()
            Text(snapshot.temperature.map { String(format: "%.1f °C", $0) } ?? "--.- °C")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LiquidGlassTheme.primaryText)
            Text(snapshot.targetTemperature.map { String(format: "Soll %.1f°", $0) } ?? "")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
        .padding(13)
        .liquidGlassInset(cornerRadius: 14)
    }

    private func biasCorrectedPanel(_ combined: BiasCorrectedRoomMeasurement) -> some View {
        let correction = combined.correction
        let statusColor: Color = correction.isProvisional ? .orange : LiquidGlassTheme.mint
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Kombinierter Raumwert").font(.subheadline.weight(.semibold))
                Spacer()
                Text(correction.isProvisional ? "Bias-korrigiert · vorläufig" : "Bias-korrigiert")
                    .font(.caption2.weight(.semibold)).foregroundStyle(statusColor)
            }
            measurementRows(combined.measurement)
            Text("Korrektur \(combined.adjustedSensorName): \(signed(correction.temperatureAdjustment)) °C · \(signed(correction.relativeHumidityAdjustment)) %-Pkt. rF")
                .font(.caption2).foregroundStyle(statusColor)
            if let caveat = correction.caveat {
                Text(caveat).font(.caption2).foregroundStyle(.orange)
            }
            Text("Sensor 1 (\(combined.baselineSensorName)) ist die Vergleichsbasis; danach 1:1 gemittelt. Basis: \(correction.sampleCount) Messpaare, \(correction.analysisPeriod).")
                .font(.caption2).foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .padding(14)
        .liquidGlassInset(cornerRadius: 15)
    }

    private func sensorPanel(_ sensor: RoomSensorObservation, index: Int, sensorCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(sensorCount > 1 ? "Sensor \(index + 1) · \(sensor.name)" : sensor.name)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(LiquidGlassTheme.primaryText)
                Spacer()
                Text(originLabel(sensor.origin)).font(.caption2).foregroundStyle(LiquidGlassTheme.tertiaryText)
            }
            measurementRows(sensor.measurement)
        }
        .padding(14)
        .liquidGlassInset(cornerRadius: 15)
    }

    private func measurementRows(_ measurement: ClimateMeasurement) -> some View {
        VStack(spacing: 0) {
            ClimateRow(label: "Temperatur", value: String(format: "%.1f °C", measurement.temperature))
            ClimateRow(label: "Luftfeuchtigkeit", value: String(format: "%.0f %%", measurement.humidity))
            ClimateRow(label: "Taupunkt", value: String(format: "%.1f °C", ClimateCalculator.dewPoint(temperatureCelsius: measurement.temperature, relativeHumidity: measurement.humidity)))
            ClimateRow(label: "Absolute Luftfeuchtigkeit", value: String(format: "%.1f g/m³", ClimateCalculator.absoluteHumidity(temperatureCelsius: measurement.temperature, relativeHumidity: measurement.humidity)))
        }
    }

    private var displayMeasurement: ClimateMeasurement? {
        if let corrected = room?.biasCorrectedMeasurement?.measurement { return corrected }
        guard let sensors = room?.sensors, !sensors.isEmpty else { return nil }
        return ClimateMeasurement(
            temperature: sensors.map(\.measurement.temperature).reduce(0, +) / Double(sensors.count),
            humidity: sensors.map(\.measurement.humidity).reduce(0, +) / Double(sensors.count)
        )
    }

    private var temperatureText: String {
        displayMeasurement.map { String(format: "%.1f °C", $0.temperature) } ?? "--.- °C"
    }

    private var thermostatSummary: String {
        guard !thermostatSnapshots.isEmpty else { return "0/\(expectedThermostatCount)" }
        let active = thermostatSnapshots.filter { $0.isEnabled == true }.count
        return "\(active)/\(expectedThermostatCount) aktiv"
    }

    private var targetSummary: String {
        guard let target = thermostatSnapshots.compactMap(\.targetTemperature).first else {
            return "Noch nicht verbunden"
        }
        return String(format: "Soll %.1f°", target)
    }

    private var summaryTint: Color {
        if windowOpen || heatingControl?.isSuspended(roomID: roomID) == true { return .orange }
        guard heatingEnabled, !thermostatSnapshots.isEmpty else { return LiquidGlassTheme.cyan }
        return thermostatSnapshots.contains { $0.isEnabled == true } ? .red : LiquidGlassTheme.cyan
    }

    private func thermostatTint(_ snapshot: HeatingThermostatSnapshot) -> Color {
        if windowOpen || heatingControl?.isSuspended(roomID: roomID) == true { return .orange }
        guard heatingEnabled else { return .gray }
        return snapshot.isEnabled == true ? .red : LiquidGlassTheme.cyan
    }

    private func thermostatStatus(_ snapshot: HeatingThermostatSnapshot) -> String {
        if windowOpen { return "Fenster offen · Heizung ausgeschaltet" }
        guard heatingEnabled else { return "Heizung aus · nicht berücksichtigt" }
        if heatingControl?.isSuspended(roomID: roomID) == true { return "Für Stosslüftung ausgeschaltet" }
        return snapshot.isEnabled == true ? "Heizkörper ein" : "Heizkörper aus"
    }

    private func signed(_ value: Double) -> String { String(format: "%+.1f", value) }

    private func originLabel(_ origin: RoomSensorOrigin) -> String {
        switch origin {
        case .mainConnector: return "Hauptmessung"
        case .additionalConnector: return "Zusatzmessung"
        case .fallback: return "Ersatzmessung · bias-korrigiert"
        }
    }
}
