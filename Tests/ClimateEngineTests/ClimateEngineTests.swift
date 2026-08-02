import Foundation
import Testing
@testable import ClimateEngine

@Test
func defaultPathsUseApplicationSupport() {
    let homeDirectory = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    let paths = ClimateEnginePaths(homeDirectory: homeDirectory)
    let expectedDirectory = homeDirectory
        .appendingPathComponent("Library/Application Support/ClimateEngine")

    #expect(paths.dataDirectory == expectedDirectory)
    #expect(paths.stateDirectory == expectedDirectory)
    #expect(paths.snapshotURL == expectedDirectory.appendingPathComponent("current.json"))
    #expect(paths.weatherSnapshotURL == expectedDirectory.appendingPathComponent("weather/current.json"))
    #expect(paths.weatherHistoryDirectory == expectedDirectory.appendingPathComponent("weather/history"))
}

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
func notificationManagerUsesOvernightOpeningWindow() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let beforeFive = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 1, hour: 4, minute: 59)
    )!
    let atFive = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 1, hour: 5)
    )!
    let manager = NotificationManager()

    #expect(manager.evaluate(
        recommendation: .ventilate,
        state: .waitingForOpening,
        now: beforeFive,
        calendar: calendar
    ).action == .openWindows)
    #expect(manager.evaluate(
        recommendation: .ventilate,
        state: .waitingForOpening,
        now: atFive,
        calendar: calendar
    ).action == .none)
}

@Test
func notificationManagerClosesThroughElevenFiftyNine() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let beforeNoon = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 1, hour: 11, minute: 59)
    )!
    let atNoon = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 1, hour: 12)
    )!
    let manager = NotificationManager()

    #expect(manager.evaluate(
        recommendation: .closeWindows,
        state: .waitingForClosing,
        now: beforeNoon,
        calendar: calendar
    ).action == .closeWindows)
    #expect(manager.evaluate(
        recommendation: .closeWindows,
        state: .waitingForClosing,
        now: atNoon,
        calendar: calendar
    ).action == .none)
}

@Test
func windowStateSurvivesMidnight() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let beforeMidnight = calendar.date(
        from: DateComponents(year: 2026, month: 7, day: 31, hour: 23, minute: 59)
    )!
    let afterMidnight = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 1, hour: 5)
    )!
    let store = WindowStateStore(
        fileURL: temporaryDirectory.appendingPathComponent("windowState.json"),
        calendar: calendar
    )

    try store.save(.waitingForClosing, now: beforeMidnight)

    #expect(try store.load(now: afterMidnight) == .waitingForClosing)
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

@Test
func completeMultiSensorCLIRunStoresAllReadings() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    let runDate = ISO8601DateFormatter().date(from: "2026-08-02T20:15:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let input = """
    22.5
    52
    21.3
    58
    21.8
    55
    22.9
    50
    23.5
    61
    19.5
    65
    """

    _ = try ClimateEngineCommand(
        paths: paths,
        now: { runDate }
    ).run(arguments: [], standardInput: input)

    let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
    #expect(snapshot.version == 2)
    #expect(snapshot.indoorRooms.map(\.name) == [
        "Stube", "Schlafzimmer", "Büro Alois", "Sauna"
    ])
    #expect(snapshot.outdoorSensors.map(\.name) == [
        "Eve Degree", "HomePod Terrasse"
    ])
    #expect(snapshot.indoor.temperature == 22.5)
    #expect(snapshot.outdoor.temperature == 21.3)

    let entries = try HistoryReader(directory: paths.historyDirectory)
        .loadToday(now: runDate)
    #expect(entries.count == 1)
    #expect(entries[0].indoorRooms.count == 4)
    #expect(entries[0].outdoorSensors.count == 2)
    #expect(entries[0].indoorRooms.last?.measurement.temperature == 23.5)
    #expect(entries[0].outdoorSensors.last?.measurement.temperature == 19.5)
}

@Test
func legacySnapshotProvidesReferenceSensorNames() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    let url = temporaryDirectory.appendingPathComponent("current.json")
    let json = """
    {
      "version": 1,
      "timestamp": "2026-08-02T06:00:00Z",
      "source": "ClimateEngineCLI",
      "indoor": { "temperature": "22.5 °C", "humidity": 52 },
      "outdoor": { "temperature": "19.5 °C", "humidity": 65 }
    }
    """
    try json.write(to: url, atomically: true, encoding: .utf8)

    let snapshot = try SensorSnapshotLoader().load(from: url)

    #expect(snapshot.indoorRooms.map(\.name) == ["Stube"])
    #expect(snapshot.outdoorSensors.map(\.name) == ["Eve Degree"])
    #expect(snapshot.indoorRooms[0].isPrimary)
    #expect(snapshot.outdoorSensors[0].isPrimary)
}

@Test
func incompleteSupplementalInputKeepsSafeReferencePair() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )

    _ = try ClimateEngineCommand(paths: paths).run(
        arguments: ["22.5", "52", "21.3", "58", "21.8", "55"],
        standardInput: ""
    )

    let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
    #expect(snapshot.indoorRooms.map(\.name) == ["Stube"])
    #expect(snapshot.outdoorSensors.map(\.name) == ["Eve Degree"])
}

@Test
func weatherInputParserAcceptsShortcutText() throws {
    let runDate = ISO8601DateFormatter().date(from: "2026-08-02T14:37:00Z")!
    let input = """
    CLIMATEENGINE_WEATHER_V1
    LOCATION|Platz 3
    CURRENT|NOW|21,4 °C|73 %|Leicht bewölkt||8,5 km/h|
    FORECAST|+1|20,8 °C|0,75|Bewölkt|0,4|7 km/h|0 mm
    FORECAST|2026-08-02T16:00:00Z|19,9 °C|81 %|Leichter Regen|65 %|10 km/h|0,4 mm
    """

    let snapshot = try WeatherInputParser().parse(input, now: runDate)

    #expect(snapshot.location == "Platz 3")
    #expect(snapshot.timestamp == runDate)
    #expect(snapshot.current.timestamp == runDate)
    #expect(snapshot.current.temperature == 21.4)
    #expect(snapshot.current.humidity == 73)
    #expect(snapshot.current.precipitationChance == nil)
    #expect(snapshot.current.windSpeed == 8.5)
    #expect(snapshot.hourlyForecast.count == 2)
    #expect(snapshot.hourlyForecast[0].timestamp == ISO8601DateFormatter().date(
        from: "2026-08-02T15:00:00Z"
    ))
    #expect(snapshot.hourlyForecast[0].humidity == 75)
    #expect(snapshot.hourlyForecast[0].precipitationChance == 40)
    #expect(snapshot.hourlyForecast[1].precipitationAmount == 0.4)
}

@Test
func completeWeatherConnectorRunWritesSnapshotAndDailyHistory() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    let runDate = ISO8601DateFormatter().date(from: "2026-08-02T14:37:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let input = """
    CLIMATEENGINE_WEATHER_V1
    LOCATION|Platz 3
    CURRENT|NOW|21.4 °C|73 %|Leicht bewölkt||8.5 km/h|
    FORECAST|+1|20.8 °C|75 %|Bewölkt|40 %|7 km/h|0 mm
    """

    let output = try ClimateEngineCommand(
        paths: paths,
        now: { runDate }
    ).run(arguments: ["weather"], standardInput: input)

    #expect(output == "WEATHER_SAVED")
    #expect(FileManager.default.fileExists(atPath: paths.weatherSnapshotURL.path))
    #expect(FileManager.default.fileExists(atPath: paths.snapshotURL.path) == false)

    let snapshot = try WeatherSnapshotStore().load(from: paths.weatherSnapshotURL)
    #expect(snapshot.location == "Platz 3")
    #expect(snapshot.current.condition == "Leicht bewölkt")
    #expect(snapshot.hourlyForecast.count == 1)

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let historyURL = paths.weatherHistoryDirectory
        .appendingPathComponent(formatter.string(from: runDate) + ".jsonl")
    let historyText = try String(contentsOf: historyURL, encoding: .utf8)
    #expect(historyText.split(separator: "\n").count == 1)
}

@Test
func malformedWeatherInputDoesNotReplaceExistingSnapshot() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    let runDate = ISO8601DateFormatter().date(from: "2026-08-02T14:37:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let existing = WeatherSnapshot(
        timestamp: runDate,
        location: "Bestehender Ort",
        current: WeatherReading(
            timestamp: runDate,
            temperature: 20,
            humidity: 50,
            condition: "Klar"
        ),
        hourlyForecast: []
    )
    try WeatherSnapshotStore().write(existing, to: paths.weatherSnapshotURL)

    #expect(throws: (any Error).self) {
        try ClimateEngineCommand(
            paths: paths,
            now: { runDate }
        ).run(
            arguments: ["weather"],
            standardInput: "CURRENT|NOW|keine Zahl|73 %|Bewölkt||8 km/h"
        )
    }

    let unchanged = try WeatherSnapshotStore().load(from: paths.weatherSnapshotURL)
    #expect(unchanged == existing)
}
