import Foundation

public struct SeasonalVentilationAdvisor {
    public let comfortFloorTemperature: Double
    public let dryingThreshold: Double

    public init(
        comfortFloorTemperature: Double = 22,
        dryingThreshold: Double = 0.3
    ) {
        self.comfortFloorTemperature = comfortFloorTemperature
        self.dryingThreshold = dryingThreshold
    }

    public func evaluate(
        snapshot: SensorSnapshot,
        weather: WeatherSnapshot?,
        operatingState: OperatingModeState,
        productionAnalysis: VentilationAnalysis,
        previousMode: OperatingMode? = nil,
        now: Date
    ) -> SeasonalRecommendationSnapshot {
        let mode = OperatingModeResolver.resolve(
            state: operatingState,
            snapshot: snapshot,
            weather: weather,
            previousMode: previousMode,
            now: now
        )
        let indoor = snapshot.indoor
        let outdoor = StableVentilationAdvisor.outdoorMean(from: snapshot.outdoorSensors)
        let indoorAbsoluteHumidity = absoluteHumidity(indoor)
        let outdoorAbsoluteHumidity = absoluteHumidity(outdoor)
        let dryingBenefit = indoorAbsoluteHumidity - outdoorAbsoluteHumidity

        let decision: Decision
        switch mode {
        case .summer:
            decision = summerDecision(productionAnalysis)
        case .transition:
            decision = transitionDecision(
                indoor: indoor,
                outdoor: outdoor,
                indoorAbsoluteHumidity: indoorAbsoluteHumidity,
                dryingBenefit: dryingBenefit,
                weather: weather,
                now: now
            )
        case .heating:
            decision = heatingDecision(
                indoor: indoor,
                outdoor: outdoor,
                indoorAbsoluteHumidity: indoorAbsoluteHumidity,
                dryingBenefit: dryingBenefit,
                weather: weather,
                now: now
            )
        }

        return SeasonalRecommendationSnapshot(
            timestamp: now,
            sensorTimestamp: snapshot.timestamp,
            selectedMode: operatingState.selection,
            effectiveMode: mode,
            heatingEnabled: operatingState.heatingEnabled,
            recommendation: decision.recommendation,
            suggestedDurationMinutes: decision.duration,
            suggestedStartAt: decision.startAt,
            indoorTemperature: indoor.temperature,
            outdoorTemperature: outdoor.temperature,
            indoorRelativeHumidity: indoor.humidity,
            indoorAbsoluteHumidity: indoorAbsoluteHumidity,
            outdoorAbsoluteHumidity: outdoorAbsoluteHumidity,
            comfortFloorTemperature: comfortFloorTemperature,
            productionRecommendation: productionAnalysis.recommendation,
            explanation: decision.explanation
        )
    }

    private func summerDecision(_ analysis: VentilationAnalysis) -> Decision {
        switch analysis.recommendation {
        case .ventilate:
            return Decision(
                recommendation: .extendedVentilation,
                explanation: "Sommer-Kandidat: Die bestehende produktive Lüftungsempfehlung wird unverändert gespiegelt."
            )
        case .neutral:
            return Decision(
                recommendation: .wait,
                explanation: "Sommer-Kandidat: Innen- und Aussenluft unterscheiden sich nur gering."
            )
        case .closeWindows:
            return Decision(
                recommendation: .keepClosed,
                explanation: "Sommer-Kandidat: Die bestehende produktive Schliess-Empfehlung wird unverändert gespiegelt."
            )
        }
    }

    private func transitionDecision(
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement,
        indoorAbsoluteHumidity: Double,
        dryingBenefit: Double,
        weather: WeatherSnapshot?,
        now: Date
    ) -> Decision {
        guard dryingBenefit > dryingThreshold else {
            return Decision(
                recommendation: .keepClosed,
                explanation: "Übergangs-Kandidat: Die Aussenluft bietet keinen ausreichenden Trocknungsvorteil."
            )
        }

        let predictedTemperature = predictedIndoorTemperature(
            indoor: indoor.temperature,
            outdoor: outdoor.temperature,
            minutes: 10
        )
        guard predictedTemperature >= comfortFloorTemperature else {
            return Decision(
                recommendation: .wait,
                explanation: String(
                    format: "Übergangs-Kandidat: Zehn Minuten Lüften könnten die Stube unter die Komfortgrenze von %.1f °C bringen.",
                    comfortFloorTemperature
                )
            )
        }

        if indoor.humidity < 60,
           let warmer = warmerDryOpportunity(
               than: outdoor.temperature,
               indoorAbsoluteHumidity: indoorAbsoluteHumidity,
               weather: weather,
               now: now
           ) {
            return Decision(
                recommendation: .wait,
                startAt: warmer.timestamp,
                explanation: String(
                    format: "Übergangs-Kandidat: Auf die wärmere, weiterhin trockene Aussenluft um %@ warten.",
                    shortTime(warmer.timestamp)
                )
            )
        }

        return Decision(
            recommendation: .briefVentilation,
            duration: 10,
            explanation: "Übergangs-Kandidat: Zehn Minuten Stosslüften trocknen, ohne die Komfortgrenze voraussichtlich zu unterschreiten."
        )
    }

    private func heatingDecision(
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement,
        indoorAbsoluteHumidity: Double,
        dryingBenefit: Double,
        weather: WeatherSnapshot?,
        now: Date
    ) -> Decision {
        guard dryingBenefit > dryingThreshold else {
            return Decision(
                recommendation: .keepClosed,
                explanation: "Heiz-Kandidat: Ohne Trocknungsvorteil rechtfertigt die Aussenluft den Wärmeverlust nicht."
            )
        }

        let humidityIsUrgent = indoor.humidity >= 60
        if !humidityIsUrgent,
           indoor.temperature <= comfortFloorTemperature {
            return Decision(
                recommendation: .wait,
                explanation: String(
                    format: "Heiz-Kandidat: Die Stube liegt bereits an der Komfortgrenze von %.1f °C; auf ein wärmeres Lüftungsfenster warten.",
                    comfortFloorTemperature
                )
            )
        }

        if !humidityIsUrgent,
           let warmer = warmerDryOpportunity(
               than: outdoor.temperature,
               indoorAbsoluteHumidity: indoorAbsoluteHumidity,
               weather: weather,
               now: now
           ) {
            return Decision(
                recommendation: .wait,
                startAt: warmer.timestamp,
                explanation: String(
                    format: "Heiz-Kandidat: Um %@ wird trockenere und mindestens 1 °C wärmere Aussenluft erwartet.",
                    shortTime(warmer.timestamp)
                )
            )
        }

        let duration = outdoor.temperature <= 5 ||
            indoor.temperature - outdoor.temperature >= 15 ? 3 : 5
        return Decision(
            recommendation: .briefVentilation,
            duration: duration,
            explanation: "Heiz-Kandidat: Kurz und vollständig öffnen; die Dauer begrenzt den Wärmeverlust bei ausreichendem Trocknungsvorteil."
        )
    }

    private func warmerDryOpportunity(
        than currentTemperature: Double,
        indoorAbsoluteHumidity: Double,
        weather: WeatherSnapshot?,
        now: Date
    ) -> WeatherReading? {
        guard let weather,
              abs(now.timeIntervalSince(weather.timestamp)) <= 90 * 60 else {
            return nil
        }
        let horizon = now.addingTimeInterval(6 * 60 * 60)
        return weather.hourlyForecast
            .filter {
                $0.timestamp >= now &&
                    $0.timestamp <= horizon &&
                    $0.temperature >= currentTemperature + 1 &&
                    $0.absoluteHumidity <= indoorAbsoluteHumidity - dryingThreshold
            }
            .max { $0.temperature < $1.temperature }
    }

    private func predictedIndoorTemperature(
        indoor: Double,
        outdoor: Double,
        minutes: Int
    ) -> Double {
        let temperatureDifference = max(0, indoor - outdoor)
        let cooling = min(1.5, temperatureDifference * 0.007 * Double(minutes))
        return indoor - cooling
    }

    private func absoluteHumidity(_ measurement: ClimateMeasurement) -> Double {
        ClimateCalculator.absoluteHumidity(
            temperatureCelsius: measurement.temperature,
            relativeHumidity: measurement.humidity
        )
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private struct Decision {
        let recommendation: SeasonalVentilationRecommendation
        let duration: Int?
        let startAt: Date?
        let explanation: String

        init(
            recommendation: SeasonalVentilationRecommendation,
            duration: Int? = nil,
            startAt: Date? = nil,
            explanation: String
        ) {
            self.recommendation = recommendation
            self.duration = duration
            self.startAt = startAt
            self.explanation = explanation
        }
    }
}
