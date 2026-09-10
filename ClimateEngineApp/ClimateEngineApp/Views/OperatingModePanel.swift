import SwiftUI
import ClimateEngine

struct OperatingModePanel: View {
    let state: OperatingModeState
    let effectiveMode: OperatingMode
    let shadowRecommendation: SeasonalRecommendationSnapshot?
    let ventilationSession: VentilationSession?
    let errorMessage: String?
    let onHeatingChanged: (Bool) -> Void
    let onSelectionChanged: (OperatingModeSelection) -> Void
    let onVentilationStarted: () -> Void
    let onVentilationStopped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 16) {
                LiquidGlassIcon(
                    systemName: effectiveMode == .heating ? "flame.fill" : "dial.medium.fill",
                    tint: effectiveMode == .heating ? .orange : LiquidGlassTheme.mint,
                    size: 44,
                    symbolSize: 19
                )

                VStack(alignment: .leading, spacing: 4) {
                    LiquidGlassSectionLabel(text: "Saisonsteuerung")
                    Text("Betriebsart")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(activeModeDescription)
                        .font(.subheadline)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(effectiveModeTitle)
                        .font(.headline)
                        .foregroundStyle(effectiveMode == .heating ? .orange : LiquidGlassTheme.mint)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .liquidGlassInset(cornerRadius: 99)

                    Toggle(
                        "Heizung ein",
                        isOn: Binding(
                            get: { state.heatingEnabled },
                            set: onHeatingChanged
                        )
                    )
                    .toggleStyle(.switch)
                    .font(.subheadline.weight(.semibold))
                    .tint(.orange)
                }
            }

            HStack(spacing: 8) {
                selectionButton(.automatic, title: "Auto")
                selectionButton(.summer, title: "Sommer")
                selectionButton(.transition, title: "Übergang")
                modeChip(
                    title: "Heizen",
                    isSelected: effectiveMode == .heating,
                    isEnabled: false
                )
            }
            .padding(6)
            .liquidGlassInset(cornerRadius: 15)

            HStack(alignment: .top, spacing: 14) {
                LiquidGlassIndicatorIcon(
                    systemName: "eye.fill",
                    tint: LiquidGlassTheme.cyan,
                    size: 28,
                    symbolSize: 11,
                    vibrant: true
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Schattenmodus · keine Auswirkung auf SMS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(LiquidGlassTheme.cyan)
                    Text(shadowTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(shadowExplanation)
                        .font(.caption)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .liquidGlassInset(cornerRadius: 16)

            HStack(spacing: 14) {
                LiquidGlassIndicatorIcon(
                    systemName: ventilationIsActive ? "wind" : "window.vertical.closed",
                    tint: ventilationIsActive ? .orange : LiquidGlassTheme.mint,
                    size: 28,
                    symbolSize: 12,
                    vibrant: ventilationIsActive
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(ventilationIsActive ? "Stosslüftung aktiv" : "Stosslüftung")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(ventilationStatusText)
                        .font(.caption)
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                Spacer()

                Button(ventilationIsActive ? "Vorzeitig beenden" : "10 Minuten starten") {
                    ventilationIsActive ? onVentilationStopped() : onVentilationStarted()
                }
                .buttonStyle(.borderedProminent)
                .tint(ventilationIsActive ? .orange : LiquidGlassTheme.petrol)
            }
            .padding(14)
            .liquidGlassInset(cornerRadius: 16)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(
            glowColor: effectiveMode == .heating ? .orange : LiquidGlassTheme.mint
        )
    }

    private func selectionButton(
        _ selection: OperatingModeSelection,
        title: String
    ) -> some View {
        Button {
            onSelectionChanged(selection)
        } label: {
            modeChip(
                title: title,
                isSelected: !state.heatingEnabled && state.selection == selection,
                isEnabled: !state.heatingEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(state.heatingEnabled)
    }

    private func modeChip(
        title: String,
        isSelected: Bool,
        isEnabled: Bool
    ) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(isSelected ? Color.white : LiquidGlassTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                            ? (title == "Heizen" ? Color.orange.opacity(0.28) : LiquidGlassTheme.petrol.opacity(0.68))
                            : Color.clear
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        }
                    }
            }
            .opacity(isEnabled || isSelected ? 1 : 0.62)
    }

    private var activeModeDescription: String {
        if state.heatingEnabled {
            return "Heizschalter ein · Stosslüftung wird beobachtet"
        }
        if state.selection == .automatic {
            return "Auto folgt aktuell der Betriebsart \(effectiveModeTitle)"
        }
        return "Manuell auf \(effectiveModeTitle) gesetzt"
    }

    private var effectiveModeTitle: String {
        switch effectiveMode {
        case .summer: return "Sommer"
        case .transition: return "Übergang"
        case .heating: return "Heizen"
        }
    }

    private var shadowTitle: String {
        guard let shadowRecommendation else {
            return "Die nächste Hauptmessung erstellt die erste Kandidatenempfehlung."
        }
        switch shadowRecommendation.recommendation {
        case .extendedVentilation:
            return "Kandidat: Dauerlüften"
        case .briefVentilation:
            if let duration = shadowRecommendation.suggestedDurationMinutes {
                return "Kandidat: \(duration) Minuten Stosslüften"
            }
            return "Kandidat: Stosslüften"
        case .wait:
            if let start = shadowRecommendation.suggestedStartAt {
                return "Kandidat: Bis \(start.formatted(date: .omitted, time: .shortened)) warten"
            }
            return "Kandidat: Abwarten"
        case .keepClosed:
            return "Kandidat: Fenster geschlossen halten"
        }
    }

    private var shadowExplanation: String {
        shadowRecommendation?.explanation
            ?? "Die produktive Sommerlogik bleibt unverändert aktiv."
    }

    private var ventilationIsActive: Bool {
        ventilationSession?.isActive() ?? false
    }

    private var ventilationStatusText: String {
        guard ventilationIsActive, let ventilationSession else {
            return "Erwartbare Abkühlung wird im Normalbetrieb geprüft."
        }
        let minutes = max(1, Int(ceil(Double(ventilationSession.remainingSeconds()) / 60)))
        return "Noch ca. \(minutes) Minuten · endet automatisch um \(ventilationSession.expiresAt.formatted(date: .omitted, time: .shortened))"
    }
}
