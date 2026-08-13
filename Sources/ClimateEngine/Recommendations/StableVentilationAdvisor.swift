import Foundation

public struct StableVentilationResult: Equatable, Sendable {
    public let snapshot: RecommendationSnapshot
    public let state: RecommendationStabilityState
    public let weatherAdvisoryChanged: Bool
}

public struct StableVentilationAdvisor {
    public let transitionInterval: TimeInterval
    public let sampleCount: Int

    public init(
        transitionInterval: TimeInterval = 15 * 60,
        sampleCount: Int = 3
    ) {
        self.transitionInterval = transitionInterval
        self.sampleCount = sampleCount
    }

    public func evaluate(
        snapshot: SensorSnapshot,
        weather: WeatherSnapshot?,
        previousState: RecommendationStabilityState?,
        now: Date
    ) -> StableVentilationResult {
        let sample = RecommendationMeasurementSample(
            timestamp: snapshot.timestamp,
            indoor: snapshot.indoor,
            outdoor: Self.outdoorMean(from: snapshot.outdoorSensors)
        )
        var samples = (previousState?.samples ?? []).filter {
            $0.timestamp != sample.timestamp &&
                now.timeIntervalSince($0.timestamp) >= 0 &&
                now.timeIntervalSince($0.timestamp) <= 30 * 60
        }
        samples.append(sample)
        samples = Array(samples.sorted { $0.timestamp < $1.timestamp }.suffix(sampleCount))

        let smoothedIndoor = Self.smoothedMeasurement(samples.map(\.indoor))
        let smoothedOutdoor = Self.smoothedMeasurement(samples.map(\.outdoor))
        let rawAnalysis = VentilationAdvisor.analyze(
            indoor: smoothedIndoor,
            outdoor: smoothedOutdoor
        )

        guard let previousState else {
            let advisory = weatherAdvisory(
                weather: weather,
                recommendation: rawAnalysis.recommendation,
                now: now
            )
            let analysis = adding(advisory: advisory, to: rawAnalysis)
            return StableVentilationResult(
                snapshot: RecommendationSnapshot(
                    timestamp: now,
                    analysis: analysis,
                    weatherAdvisory: advisory
                ),
                state: RecommendationStabilityState(
                    samples: samples,
                    effectiveRecommendation: rawAnalysis.recommendation,
                    notifiedWeatherAdvisory: advisory?.kind
                ),
                weatherAdvisoryChanged: advisory != nil
            )
        }

        let effective = previousState.effectiveRecommendation
        let desired = desiredRecommendation(
            rawAnalysis: rawAnalysis,
            effective: effective,
            weather: weather,
            indoor: smoothedIndoor,
            outdoor: smoothedOutdoor,
            now: now
        )
        let isImmediateClose = effective == .ventilate &&
            desired == .closeWindows &&
            isClearCounterTrend(
                weather: weather,
                indoor: smoothedIndoor,
                outdoor: smoothedOutdoor,
                now: now
            )

        let nextEffective: VentilationRecommendation
        let candidate: VentilationRecommendation?
        let candidateSince: Date?
        let transitionPending: Bool

        if desired == effective {
            nextEffective = effective
            candidate = nil
            candidateSince = nil
            transitionPending = false
        } else if isImmediateClose {
            nextEffective = .closeWindows
            candidate = nil
            candidateSince = nil
            transitionPending = false
        } else if previousState.candidateRecommendation == desired,
                  let since = previousState.candidateSince,
                  now.timeIntervalSince(since) >= transitionInterval {
            nextEffective = desired
            candidate = nil
            candidateSince = nil
            transitionPending = false
        } else {
            nextEffective = effective
            candidate = desired
            candidateSince = previousState.candidateRecommendation == desired
                ? previousState.candidateSince ?? now
                : now
            transitionPending = true
        }

        var effectiveAnalysis = analysis(
            for: nextEffective,
            basedOn: rawAnalysis,
            heldFrom: effective,
            transitionPending: transitionPending
        )
        let advisory = weatherAdvisory(
            weather: weather,
            recommendation: nextEffective,
            now: now
        )
        effectiveAnalysis = adding(advisory: advisory, to: effectiveAnalysis)

        let notifiedAdvisory = nextEffective == .ventilate ? advisory?.kind : nil
        return StableVentilationResult(
            snapshot: RecommendationSnapshot(
                timestamp: now,
                analysis: effectiveAnalysis,
                weatherAdvisory: advisory,
                isTransitionPending: transitionPending
            ),
            state: RecommendationStabilityState(
                samples: samples,
                effectiveRecommendation: nextEffective,
                candidateRecommendation: candidate,
                candidateSince: candidateSince,
                notifiedWeatherAdvisory: notifiedAdvisory
            ),
            weatherAdvisoryChanged: notifiedAdvisory != nil &&
                notifiedAdvisory != previousState.notifiedWeatherAdvisory
        )
    }

    public static func outdoorMean(from readings: [SensorReading]) -> ClimateMeasurement {
        let measurements = readings.map(\.measurement)
        guard !measurements.isEmpty else {
            return ClimateMeasurement(temperature: 0, humidity: 0)
        }
        return smoothedMeasurement(measurements)
    }

    private static func smoothedMeasurement(
        _ measurements: [ClimateMeasurement]
    ) -> ClimateMeasurement {
        guard !measurements.isEmpty else {
            return ClimateMeasurement(temperature: 0, humidity: 0)
        }
        let temperature = measurements.map(\.temperature).reduce(0, +) /
            Double(measurements.count)
        let absoluteHumidity = measurements.map {
            ClimateCalculator.absoluteHumidity(
                temperatureCelsius: $0.temperature,
                relativeHumidity: $0.humidity
            )
        }.reduce(0, +) / Double(measurements.count)
        return ClimateMeasurement(
            temperature: temperature,
            humidity: ClimateCalculator.relativeHumidity(
                temperatureCelsius: temperature,
                absoluteHumidity: absoluteHumidity
            )
        )
    }

    private func desiredRecommendation(
        rawAnalysis: VentilationAnalysis,
        effective: VentilationRecommendation,
        weather: WeatherSnapshot?,
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement,
        now: Date
    ) -> VentilationRecommendation {
        guard effective == .ventilate,
              rawAnalysis.recommendation != .ventilate else {
            return rawAnalysis.recommendation
        }
        if isClearCounterTrend(
            weather: weather,
            indoor: indoor,
            outdoor: outdoor,
            now: now
        ) {
            return .closeWindows
        }
        if forecastSupportsContinuedVentilation(
            weather: weather,
            indoor: indoor,
            outdoor: outdoor,
            now: now
        ) {
            return .ventilate
        }
        return rawAnalysis.recommendation
    }

    private func forecastSupportsContinuedVentilation(
        weather: WeatherSnapshot?,
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement,
        now: Date
    ) -> Bool {
        guard let weather, now.timeIntervalSince(weather.timestamp) <= 90 * 60 else {
            return false
        }
        let forecast = nextTwoHours(weather: weather, now: now)
        guard !forecast.isEmpty else { return false }
        let indoorAH = absoluteHumidity(indoor)
        let temperaturesDoNotRise = forecast.allSatisfy {
            $0.temperature <= weather.current.temperature + 0.5
        }
        let airDoesNotBecomeClearlyMoreHumid = forecast.allSatisfy {
            $0.absoluteHumidity <= indoorAH + 0.3
        }
        return temperaturesDoNotRise && airDoesNotBecomeClearlyMoreHumid
    }

    private func isClearCounterTrend(
        weather: WeatherSnapshot?,
        indoor: ClimateMeasurement,
        outdoor: ClimateMeasurement,
        now: Date
    ) -> Bool {
        let indoorAH = absoluteHumidity(indoor)
        let outdoorAH = absoluteHumidity(outdoor)
        if outdoor.temperature >= indoor.temperature + 1.0 || outdoorAH >= indoorAH + 0.8 {
            return true
        }
        guard let weather, now.timeIntervalSince(weather.timestamp) <= 90 * 60 else {
            return false
        }
        return nextTwoHours(weather: weather, now: now).contains {
            $0.temperature >= indoor.temperature + 1.0 ||
                $0.absoluteHumidity >= indoorAH + 0.8
        }
    }

    private func weatherAdvisory(
        weather: WeatherSnapshot?,
        recommendation: VentilationRecommendation,
        now: Date
    ) -> WeatherAdvisory? {
        guard recommendation == .ventilate,
              let weather,
              now.timeIntervalSince(weather.timestamp) <= 90 * 60 else {
            return nil
        }
        let readings = [weather.current] + nextTwoHours(weather: weather, now: now)
        let rain = readings.contains {
            ($0.precipitationChance ?? 0) >= 40 ||
                ($0.precipitationAmount ?? 0) > 0 ||
                Self.isRainCondition($0.condition)
        }
        let wind = readings.contains { ($0.windSpeed ?? 0) >= 20 }

        switch (rain, wind) {
        case (true, true):
            return WeatherAdvisory(
                kind: .rainAndWind,
                message: "Regen und stärkerer Wind möglich – Fenster sichern und besser nur kippen."
            )
        case (true, false):
            return WeatherAdvisory(
                kind: .rain,
                message: "Regen möglich – Fenster besser nur kippen."
            )
        case (false, true):
            return WeatherAdvisory(
                kind: .wind,
                message: "Stärkerer Wind möglich – Fenster sichern oder nur kippen."
            )
        case (false, false):
            return nil
        }
    }

    private func nextTwoHours(weather: WeatherSnapshot, now: Date) -> [WeatherReading] {
        let end = now.addingTimeInterval(2 * 60 * 60)
        return weather.hourlyForecast.filter {
            $0.timestamp > now && $0.timestamp <= end
        }
    }

    private static func isRainCondition(_ condition: String) -> Bool {
        let normalized = condition.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "de_CH")
        )
        return ["regen", "schauer", "gewitter", "niederschlag"].contains {
            normalized.contains($0)
        }
    }

    private func analysis(
        for recommendation: VentilationRecommendation,
        basedOn raw: VentilationAnalysis,
        heldFrom previous: VentilationRecommendation,
        transitionPending: Bool
    ) -> VentilationAnalysis {
        guard recommendation != raw.recommendation else { return raw }
        let explanation: String
        if previous == .ventilate && recommendation == .ventilate {
            explanation = "Die Temperaturen haben sich angeglichen. Da die Aussenluft voraussichtlich nicht wärmer oder deutlich feuchter wird, bleibt Lüften sinnvoll."
        } else if transitionPending {
            explanation = "Die neue Tendenz wird noch bestätigt; die bisherige Empfehlung bleibt vorerst bestehen."
        } else {
            explanation = raw.explanation
        }
        return replacing(raw, recommendation: recommendation, explanation: explanation)
    }

    private func adding(
        advisory: WeatherAdvisory?,
        to analysis: VentilationAnalysis
    ) -> VentilationAnalysis {
        guard let advisory else { return analysis }
        return replacing(
            analysis,
            recommendation: analysis.recommendation,
            explanation: analysis.explanation + " " + advisory.message
        )
    }

    private func replacing(
        _ analysis: VentilationAnalysis,
        recommendation: VentilationRecommendation,
        explanation: String
    ) -> VentilationAnalysis {
        VentilationAnalysis(
            recommendation: recommendation,
            indoorAbsoluteHumidity: analysis.indoorAbsoluteHumidity,
            outdoorAbsoluteHumidity: analysis.outdoorAbsoluteHumidity,
            absoluteHumidityDifference: analysis.absoluteHumidityDifference,
            explanation: explanation,
            indoorTemperature: analysis.indoorTemperature,
            outdoorTemperature: analysis.outdoorTemperature
        )
    }

    private func absoluteHumidity(_ measurement: ClimateMeasurement) -> Double {
        ClimateCalculator.absoluteHumidity(
            temperatureCelsius: measurement.temperature,
            relativeHumidity: measurement.humidity
        )
    }
}
