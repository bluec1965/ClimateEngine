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
        notificationSent: false,
        explanation: "Test explanation",
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
        notificationSent: false,
        explanation: "Test explanation",
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
        notificationSent: false,
        explanation: "Test explanation",
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
        notificationSent: false,
        explanation: "Test explanation",
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
        notificationSent: false,
        explanation: "Test explanation",
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
        notificationSent: false,
        explanation: "Test explanation",
    )

    #expect(policy.shouldStore(previous: nil, current: previous))
    #expect(policy.shouldStore(previous: previous, current: unchanged) == false)
    #expect(policy.shouldStore(previous: previous, current: changedRecommendation))
    #expect(policy.shouldStore(previous: previous, current: changedTemperature))
    #expect(policy.shouldStore(previous: previous, current: heartbeat))
}
@Test
func historyReaderReturnsRecommendationEvents() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)

    let now = Date()

    let entries = [
        HistoryEntry(
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
            notificationSent: false,
            explanation: "Test explanation",
        ),
        HistoryEntry(
            timestamp: now.addingTimeInterval(60),
            indoorTemperature: 24.1,
            indoorHumidity: 50.0,
            indoorAbsoluteHumidity: 10.1,
            indoorDewPoint: 13.0,
            outdoorTemperature: 20.1,
            outdoorHumidity: 60.0,
            outdoorAbsoluteHumidity: 9.1,
            outdoorDewPoint: 12.0,
            recommendation: "ventilate",
            notificationSent: false,
            explanation: "Test explanation",
        ),
        HistoryEntry(
            timestamp: now.addingTimeInterval(120),
            indoorTemperature: 24.2,
            indoorHumidity: 50.0,
            indoorAbsoluteHumidity: 10.2,
            indoorDewPoint: 13.0,
            outdoorTemperature: 21.0,
            outdoorHumidity: 60.0,
            outdoorAbsoluteHumidity: 9.5,
            outdoorDewPoint: 12.0,
            recommendation: "closeWindows",
            notificationSent: true,
            explanation: "Test explanation",
        )
    ]

    let writer = HistoryWriter(directory: temporaryDirectory)

    for entry in entries {
        try writer.append(entry)
    }

    let events = try HistoryReader(directory: temporaryDirectory).todayEvents()

    #expect(events.count == 2)
    #expect(events[0].recommendation == "ventilate")
    #expect(events[1].recommendation == "closeWindows")
    #expect(events[1].notificationSent == true)
}
@Test
func historyAnalyzerCalculatesStatistics() {
    let now = Date()

    let entries = [
        HistoryEntry(
            timestamp: now,
            indoorTemperature: 24,
            indoorHumidity: 50,
            indoorAbsoluteHumidity: 10,
            indoorDewPoint: 13,
            outdoorTemperature: 20,
            outdoorHumidity: 60,
            outdoorAbsoluteHumidity: 9,
            outdoorDewPoint: 12,
            recommendation: "ventilate",
            notificationSent: false,
            explanation: "Test"
        ),
        HistoryEntry(
            timestamp: now.addingTimeInterval(60),
            indoorTemperature: 24,
            indoorHumidity: 50,
            indoorAbsoluteHumidity: 10,
            indoorDewPoint: 13,
            outdoorTemperature: 21,
            outdoorHumidity: 60,
            outdoorAbsoluteHumidity: 9,
            outdoorDewPoint: 12,
            recommendation: "closeWindows",
            notificationSent: true,
            explanation: "Test"
        ),
        HistoryEntry(
            timestamp: now.addingTimeInterval(120),
            indoorTemperature: 24,
            indoorHumidity: 50,
            indoorAbsoluteHumidity: 10,
            indoorDewPoint: 13,
            outdoorTemperature: 19,
            outdoorHumidity: 60,
            outdoorAbsoluteHumidity: 9,
            outdoorDewPoint: 12,
            recommendation: "ventilate",
            notificationSent: false,
            explanation: "Test"
        )
    ]

    let statistics = HistoryAnalyzer().statistics(from: entries)

    #expect(statistics.measurementCount == 3)
    #expect(statistics.recommendationChanges == 2)
    #expect(statistics.ventilationPeriods == 2)
}
@Test
func windowStateRoundTrip() throws {

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)

    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    let url = directory.appendingPathComponent("windowState.json")

    let store = WindowStateStore(fileURL: url)

    try store.save(.waitingForClosing)

    let loaded = try store.load()

    #expect(loaded == .waitingForClosing)
}
@Test
func notificationManagerOpeningTransition() {

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let date = calendar.date(
        from: DateComponents(
            year: 2026,
            month: 7,
            day: 7,
            hour: 20
        )
    )!

    let result = NotificationManager().evaluate(
        recommendation: .ventilate,
        state: .waitingForOpening,
        now: date,
        calendar: calendar
    )

    #expect(result.action == .openWindows)
    #expect(result.newState == .waitingForClosing)
}
@Test
func measurementParserAcceptsFormattedValues() throws {

    #expect(try MeasurementParser.double(from: "24.4") == 24.4)
    #expect(try MeasurementParser.double(from: "24,4") == 24.4)

    #expect(try MeasurementParser.double(from: "24.4 °C") == 24.4)
    #expect(try MeasurementParser.double(from: "24,4 °C") == 24.4)

    #expect(try MeasurementParser.double(from: "53 %") == 53)
    #expect(try MeasurementParser.double(from: "53%") == 53)
}

@Test
func completeCLIRunCreatesDailyHistoryFile() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    let runDate = ISO8601DateFormatter().date(from: "2026-07-31T20:15:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )

    let output = try ClimateEngineCommand(
        paths: paths,
        now: { runDate }
    ).run(arguments: ["24.0", "50", "18.0", "50"])

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let historyURL = paths.historyDirectory
        .appendingPathComponent(formatter.string(from: runDate) + ".jsonl")

    #expect(["OPEN_WINDOWS", "NONE"].contains(output))
    #expect(FileManager.default.fileExists(atPath: paths.snapshotURL.path))
    #expect(FileManager.default.fileExists(atPath: historyURL.path))

    let entries = try HistoryReader(directory: paths.historyDirectory)
        .loadToday(now: runDate)
    #expect(entries.count == 1)
    #expect(entries.first?.timestamp == runDate)
    #expect(entries.first?.indoorTemperature == 24.0)
    #expect(entries.first?.outdoorTemperature == 18.0)
}
