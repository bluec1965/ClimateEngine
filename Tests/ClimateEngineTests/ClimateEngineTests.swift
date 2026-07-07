import Foundation
import Testing
@testable import ClimateEngine

@Test func loadCurrentSensorSnapshot() throws {
    let url = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/ClimateEngine/current.json")

    let loader = SensorSnapshotLoader()
    let snapshot = try loader.load(from: url)

    #expect(snapshot.version == 1)
    #expect(snapshot.source == "ClimateEngineCLI")

    #expect(snapshot.indoor.temperature > 0)
    #expect(snapshot.indoor.humidity > 0)
    #expect(snapshot.outdoor.temperature > 0)
    #expect(snapshot.outdoor.humidity > 0)
}
@Test
func dewPointCalculation() {
    let dewPoint = ClimateCalculator.dewPoint(
        temperatureCelsius: 24.3,
        relativeHumidity: 49
    )

    #expect(dewPoint > 12.8)
    #expect(dewPoint < 13.0)
}

@Test
func absoluteHumidityCalculation() {
    let humidity = ClimateCalculator.absoluteHumidity(
        temperatureCelsius: 24.3,
        relativeHumidity: 49
    )

    #expect(humidity > 10)
    #expect(humidity < 11)
}
@Test
func ventilationRecommendationForCurrentSnapshot() throws {
    let url = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/ClimateEngine/current.json")

    let snapshot = try SensorSnapshotLoader().load(from: url)
    let recommendation = VentilationAdvisor.recommendation(for: snapshot)

    #expect([
        VentilationRecommendation.ventilate,
        VentilationRecommendation.neutral,
        VentilationRecommendation.closeWindows
    ].contains(recommendation))
}
@Test
func historyWriterAndReaderRoundTrip() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)

    let entry = HistoryEntry(
        timestamp: Date(),
        indoorTemperature: 24.3,
        indoorHumidity: 49.0,
        indoorAbsoluteHumidity: 10.7,
        indoorDewPoint: 12.9,
        outdoorTemperature: 20.1,
        outdoorHumidity: 60.0,
        outdoorAbsoluteHumidity: 10.4,
        outdoorDewPoint: 12.0,
        recommendation: "ventilate",
        notificationSent: false
    )

    try HistoryWriter(directory: temporaryDirectory).append(entry)

    let entries = try HistoryReader(directory: temporaryDirectory).loadToday()

    #expect(entries.count == 1)
    #expect(entries.first?.indoorTemperature == 24.3)
    #expect(entries.first?.recommendation == "ventilate")
    #expect(entries.first?.notificationSent == false)
}
@Test
func historyPolicyStoresRelevantChanges() throws {
    let policy = HistoryPolicy(
        temperatureThreshold: 0.2,
        absoluteHumidityThreshold: 0.2,
        heartbeatInterval: 10 * 60
    )

    let now = Date()

    let previous = HistoryEntry(
        timestamp: now,
        indoorTemperature: 24.0,
        indoorHumidity: 50.0,
        indoorAbsoluteHumidity: 10.0,
        indoorDewPoint: 13.0,
        outdoorTemperature: 20.0,
        outdoorHumidity: 60.0,
        outdoorAbsoluteHumidity: 9.0,
        outdoorDewPoint: 12.0,
        recommendation: "ventilate",
        notificationSent: false
    )

    let unchanged = HistoryEntry(
        timestamp: now.addingTimeInterval(60),
        indoorTemperature: 24.0,
        indoorHumidity: 50.0,
        indoorAbsoluteHumidity: 10.0,
        indoorDewPoint: 13.0,
        outdoorTemperature: 20.0,
        outdoorHumidity: 60.0,
        outdoorAbsoluteHumidity: 9.0,
        outdoorDewPoint: 12.0,
        recommendation: "ventilate",
        notificationSent: false
    )

    let changedRecommendation = HistoryEntry(
        timestamp: now.addingTimeInterval(60),
        indoorTemperature: 24.0,
        indoorHumidity: 50.0,
        indoorAbsoluteHumidity: 10.0,
        indoorDewPoint: 13.0,
        outdoorTemperature: 20.0,
        outdoorHumidity: 60.0,
        outdoorAbsoluteHumidity: 9.0,
        outdoorDewPoint: 12.0,
        recommendation: "closeWindows",
        notificationSent: false
    )

    let changedTemperature = HistoryEntry(
        timestamp: now.addingTimeInterval(60),
        indoorTemperature: 24.3,
        indoorHumidity: 50.0,
        indoorAbsoluteHumidity: 10.0,
        indoorDewPoint: 13.0,
        outdoorTemperature: 20.0,
        outdoorHumidity: 60.0,
        outdoorAbsoluteHumidity: 9.0,
        outdoorDewPoint: 12.0,
        recommendation: "ventilate",
        notificationSent: false
    )

    let heartbeat = HistoryEntry(
        timestamp: now.addingTimeInterval(10 * 60),
        indoorTemperature: 24.0,
        indoorHumidity: 50.0,
        indoorAbsoluteHumidity: 10.0,
        indoorDewPoint: 13.0,
        outdoorTemperature: 20.0,
        outdoorHumidity: 60.0,
        outdoorAbsoluteHumidity: 9.0,
        outdoorDewPoint: 12.0,
        recommendation: "ventilate",
        notificationSent: false
    )

    #expect(policy.shouldStore(previous: nil, current: previous))
    #expect(policy.shouldStore(previous: previous, current: unchanged) == false)
    #expect(policy.shouldStore(previous: previous, current: changedRecommendation))
    #expect(policy.shouldStore(previous: previous, current: changedTemperature))
    #expect(policy.shouldStore(previous: previous, current: heartbeat))
}
