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
    #expect(paths.additionalSensorSnapshotURL == expectedDirectory.appendingPathComponent(
        "additional-sensors/current.json"
    ))
    #expect(paths.additionalSensorHistoryDirectory == expectedDirectory.appendingPathComponent(
        "additional-sensors/history"
    ))
    #expect(paths.sensorInputStateURL == expectedDirectory.appendingPathComponent(
        "sensor-input/validation-state.json"
    ))
    #expect(paths.sensorInputHistoryDirectory == expectedDirectory.appendingPathComponent(
        "sensor-input/history"
    ))
    #expect(paths.recommendationStateURL == expectedDirectory.appendingPathComponent(
        "recommendation/stability-state.json"
    ))
    #expect(paths.recommendationSnapshotURL == expectedDirectory.appendingPathComponent(
        "current-recommendation.json"
    ))
}

@Test
func sharedPathsUseLoginHomeInsteadOfSandboxContainer() {
    let accountHome = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    let sandboxHome = accountHome.appendingPathComponent(
        "Library/Containers/io.example.ClimateEngine/Data",
        isDirectory: true
    )

    let paths = ClimateEnginePaths.shared(
        environment: [:],
        accountHomeDirectory: accountHome,
        processHomeDirectory: sandboxHome
    )

    #expect(paths.dataDirectory.path == accountHome.appendingPathComponent(
        "Library/Application Support/ClimateEngine",
        isDirectory: true
    ).path)
}

@Test
func sharedPathsHonorAbsoluteDataDirectoryOverride() {
    let configuredDirectory = "/Users/Shared/ClimateEngine-Test"
    let paths = ClimateEnginePaths.shared(
        environment: [
            ClimateEnginePaths.dataDirectoryEnvironmentKey: configuredDirectory
        ],
        accountHomeDirectory: URL(fileURLWithPath: "/Users/tester")
    )

    #expect(paths.dataDirectory.path == configuredDirectory)
    #expect(paths.stateDirectory == paths.dataDirectory)
}

@Test func loadCurrentSensorSnapshot() throws {
    let url = ClimateEnginePaths.current.snapshotURL

    let loader = SensorSnapshotLoader()
    let snapshot = try loader.load(from: url)

    #expect(snapshot.version == 2)
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
    let url = ClimateEnginePaths.current.snapshotURL

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
func historyReaderKeepsValidEntriesWhenOneLineIsMalformed() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let timestamp = ISO8601DateFormatter().date(
        from: "2026-08-19T18:42:00Z"
    )!
    let entry = HistoryEntry(
        timestamp: timestamp,
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
        explanation: "Valid entry"
    )
    try HistoryWriter(directory: temporaryDirectory).append(entry)

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let historyURL = temporaryDirectory.appendingPathComponent(
        formatter.string(from: timestamp) + ".jsonl"
    )
    let handle = try FileHandle(forWritingTo: historyURL)
    defer { handle.closeFile() }
    handle.seekToEndOfFile()
    handle.write(Data("{\"timestamp\":\n".utf8))

    let result = try HistoryReader(directory: temporaryDirectory)
        .loadTodayWithDiagnostics(now: timestamp)

    #expect(result.entries.count == 1)
    #expect(result.entries.first?.timestamp == timestamp)
    #expect(result.skippedLineCount == 1)
}
@Test
func historyPolicyStoresEveryNewMeasurementAndSkipsExactSnapshotDuplicates() throws {
    let policy = HistoryPolicy()

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

    let nextMeasurement = HistoryEntry(
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

    let duplicateSnapshot = HistoryEntry(
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

    #expect(policy.shouldStore(previous: nil, current: previous))
    #expect(policy.shouldStore(previous: previous, current: nextMeasurement))
    #expect(policy.shouldStore(previous: previous, current: duplicateSnapshot) == false)
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
func consecutiveAcceptedCLIRunsEachCreateOneHistoryMeasurement() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let firstDate = ISO8601DateFormatter().date(from: "2026-08-19T18:50:00Z")!
    let secondDate = firstDate.addingTimeInterval(5 * 60)
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )

    _ = try ClimateEngineCommand(paths: paths, now: { firstDate }).run(
        arguments: ["24.0", "50", "20.0", "60"]
    )
    _ = try ClimateEngineCommand(paths: paths, now: { secondDate }).run(
        arguments: ["24.0", "50", "20.0", "60"]
    )
    _ = try ClimateEngineCommand(
        paths: paths,
        now: { secondDate.addingTimeInterval(60) }
    ).run(arguments: [])

    let entries = try HistoryReader(directory: paths.historyDirectory)
        .loadToday(now: secondDate)
    #expect(entries.map(\.timestamp) == [firstDate, secondDate])
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
func implausibleStubeJumpDoesNotReplaceSnapshot() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let firstDate = ISO8601DateFormatter().date(from: "2026-08-09T05:00:00Z")!
    let jumpDate = firstDate.addingTimeInterval(5 * 60)

    _ = try ClimateEngineCommand(paths: paths, now: { firstDate }).run(
        arguments: ["24.0", "55", "20.0", "60"]
    )

    #expect(throws: SensorInputValidationError.self) {
        _ = try ClimateEngineCommand(paths: paths, now: { jumpDate }).run(
            arguments: ["27.0", "55", "20.0", "60"]
        )
    }

    let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
    #expect(snapshot.timestamp == firstDate)
    #expect(snapshot.indoor.temperature == 24.0)

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let auditURL = paths.sensorInputHistoryDirectory.appendingPathComponent(
        formatter.string(from: jumpDate) + ".jsonl"
    )
    let auditLines = try String(contentsOf: auditURL, encoding: .utf8)
        .split(whereSeparator: \.isNewline)
    #expect(auditLines.count == 2)
    #expect(auditLines.last?.contains("\"accepted\":false") == true)
}

@Test
func implausibleStubeJumpIsAcceptedAfterThreeConsistentReadings() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let firstDate = ISO8601DateFormatter().date(from: "2026-08-09T05:00:00Z")!

    _ = try ClimateEngineCommand(paths: paths, now: { firstDate }).run(
        arguments: ["24.0", "55", "20.0", "60"]
    )

    for (index, temperature) in [27.0, 27.1].enumerated() {
        let date = firstDate.addingTimeInterval(Double(index + 1) * 5 * 60)
        #expect(throws: SensorInputValidationError.self) {
            _ = try ClimateEngineCommand(paths: paths, now: { date }).run(
                arguments: [String(temperature), "55", "20.0", "60"]
            )
        }
    }

    let confirmedDate = firstDate.addingTimeInterval(15 * 60)
    _ = try ClimateEngineCommand(paths: paths, now: { confirmedDate }).run(
        arguments: ["26.9", "55", "20.0", "60"]
    )

    let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
    #expect(snapshot.timestamp == confirmedDate)
    #expect(snapshot.indoor.temperature == 26.9)
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
func repeatedIncompleteInputCannotReplaceCompleteMultiSensorSnapshot() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let firstDate = ISO8601DateFormatter().date(from: "2026-08-12T05:00:00Z")!
    let completeInput = [
        "23.3", "37", "22.8", "37",
        "25.5", "42", "23.0", "35",
        "22.7", "36", "22.7", "36"
    ]

    _ = try ClimateEngineCommand(paths: paths, now: { firstDate }).run(
        arguments: completeInput
    )

    for index in 1...3 {
        let runDate = firstDate.addingTimeInterval(Double(index) * 5 * 60)
        #expect(throws: SensorInputValidationError.self) {
            _ = try ClimateEngineCommand(paths: paths, now: { runDate }).run(
                arguments: ["23.3", "37", "22.8", "37"]
            )
        }
    }

    let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
    #expect(snapshot.timestamp == firstDate)
    #expect(snapshot.indoorRooms.map(\.name) == [
        "Stube", "Schlafzimmer", "Büro Alois", "Sauna"
    ])
    #expect(snapshot.outdoorSensors.map(\.name) == [
        "Eve Degree", "HomePod Terrasse"
    ])

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let auditURL = paths.sensorInputHistoryDirectory.appendingPathComponent(
        formatter.string(from: firstDate) + ".jsonl"
    )
    let auditLines = try String(contentsOf: auditURL, encoding: .utf8)
        .split(whereSeparator: \.isNewline)
    #expect(auditLines.count == 4)
    #expect(auditLines.dropFirst().allSatisfy {
        $0.contains("\"accepted\":false")
    })
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

@Test
func outdoorReferenceUsesMeanTemperatureAndAbsoluteHumidity() {
    let readings = [
        SensorReading(
            id: "eve-degree",
            name: "Eve Degree",
            measurement: ClimateMeasurement(temperature: 21.3, humidity: 60)
        ),
        SensorReading(
            id: "homepod-terrasse",
            name: "HomePod Terrasse",
            measurement: ClimateMeasurement(temperature: 19.5, humidity: 70)
        )
    ]

    let mean = StableVentilationAdvisor.outdoorMean(from: readings)
    let expectedAbsoluteHumidity = readings.map {
        ClimateCalculator.absoluteHumidity(
            temperatureCelsius: $0.measurement.temperature,
            relativeHumidity: $0.measurement.humidity
        )
    }.reduce(0, +) / 2

    #expect(abs(mean.temperature - 20.4) < 0.001)
    #expect(abs(ClimateCalculator.absoluteHumidity(
        temperatureCelsius: mean.temperature,
        relativeHumidity: mean.humidity
    ) - expectedAbsoluteHumidity) < 0.001)
}

@Test
func recommendationNeedsFifteenMinutesOfStableTendency() {
    let advisor = StableVentilationAdvisor(transitionInterval: 15 * 60)
    let start = ISO8601DateFormatter().date(from: "2026-08-13T18:00:00Z")!
    let ventilateSnapshot = recommendationTestSnapshot(
        timestamp: start,
        indoorTemperature: 24,
        indoorHumidity: 60,
        outdoorTemperature: 18,
        outdoorHumidity: 50
    )
    let initial = advisor.evaluate(
        snapshot: ventilateSnapshot,
        weather: nil,
        previousState: nil,
        now: start
    )
    #expect(initial.snapshot.analysis.recommendation == .ventilate)

    let previousVentilatingState = RecommendationStabilityState(
        samples: [],
        effectiveRecommendation: initial.state.effectiveRecommendation
    )
    let closeSnapshot = recommendationTestSnapshot(
        timestamp: start.addingTimeInterval(5 * 60),
        indoorTemperature: 24,
        indoorHumidity: 50,
        outdoorTemperature: 24.2,
        outdoorHumidity: 35
    )
    let pending = advisor.evaluate(
        snapshot: closeSnapshot,
        weather: nil,
        previousState: previousVentilatingState,
        now: start.addingTimeInterval(5 * 60)
    )
    #expect(pending.snapshot.analysis.recommendation == .ventilate)
    #expect(pending.snapshot.isTransitionPending)

    let closeSnapshot2 = recommendationTestSnapshot(
        timestamp: start.addingTimeInterval(10 * 60),
        indoorTemperature: 24,
        indoorHumidity: 50,
        outdoorTemperature: 24.2,
        outdoorHumidity: 35
    )
    let stillPending = advisor.evaluate(
        snapshot: closeSnapshot2,
        weather: nil,
        previousState: pending.state,
        now: start.addingTimeInterval(15 * 60)
    )
    #expect(stillPending.snapshot.analysis.recommendation == .ventilate)

    let closeSnapshot3 = recommendationTestSnapshot(
        timestamp: start.addingTimeInterval(20 * 60),
        indoorTemperature: 24,
        indoorHumidity: 50,
        outdoorTemperature: 24.2,
        outdoorHumidity: 35
    )
    let changed = advisor.evaluate(
        snapshot: closeSnapshot3,
        weather: nil,
        previousState: stillPending.state,
        now: start.addingTimeInterval(20 * 60)
    )
    #expect(changed.snapshot.analysis.recommendation == .closeWindows)
}

@Test
func clearCounterTrendClosesImmediately() {
    let advisor = StableVentilationAdvisor()
    let start = ISO8601DateFormatter().date(from: "2026-08-13T18:00:00Z")!
    let initial = advisor.evaluate(
        snapshot: recommendationTestSnapshot(
            timestamp: start,
            indoorTemperature: 24,
            indoorHumidity: 60,
            outdoorTemperature: 18,
            outdoorHumidity: 50
        ),
        weather: nil,
        previousState: nil,
        now: start
    )
    let warmer = recommendationTestSnapshot(
        timestamp: start.addingTimeInterval(5 * 60),
        indoorTemperature: 24,
        indoorHumidity: 50,
        outdoorTemperature: 28,
        outdoorHumidity: 70
    )
    var state = initial.state
    var result = initial
    for minute in [5, 10, 15] {
        result = advisor.evaluate(
            snapshot: warmer,
            weather: nil,
            previousState: state,
            now: start.addingTimeInterval(Double(minute * 60))
        )
        state = result.state
    }
    #expect(result.snapshot.analysis.recommendation == .closeWindows)
    #expect(result.snapshot.isTransitionPending == false)
}

@Test
func fallingForecastKeepsVentilationWhenTemperaturesConverge() {
    let advisor = StableVentilationAdvisor()
    let start = ISO8601DateFormatter().date(from: "2026-08-13T18:00:00Z")!
    let initial = advisor.evaluate(
        snapshot: recommendationTestSnapshot(
            timestamp: start,
            indoorTemperature: 24,
            indoorHumidity: 60,
            outdoorTemperature: 18,
            outdoorHumidity: 50
        ),
        weather: nil,
        previousState: nil,
        now: start
    )
    let converged = recommendationTestSnapshot(
        timestamp: start.addingTimeInterval(5 * 60),
        indoorTemperature: 22,
        indoorHumidity: 50,
        outdoorTemperature: 22,
        outdoorHumidity: 45
    )
    let weather = recommendationTestWeather(
        now: start.addingTimeInterval(5 * 60),
        temperatures: [22, 21],
        humidities: [45, 48]
    )
    let result = advisor.evaluate(
        snapshot: converged,
        weather: weather,
        previousState: initial.state,
        now: start.addingTimeInterval(5 * 60)
    )
    #expect(result.snapshot.analysis.recommendation == .ventilate)
}

@Test
func rainAndWindOnlyWarnWhileVentilating() {
    let advisor = StableVentilationAdvisor()
    let now = ISO8601DateFormatter().date(from: "2026-08-13T18:00:00Z")!
    let weather = recommendationTestWeather(
        now: now,
        temperatures: [18, 17],
        humidities: [60, 65],
        rainChance: 60,
        windSpeed: 25
    )
    let ventilating = advisor.evaluate(
        snapshot: recommendationTestSnapshot(
            timestamp: now,
            indoorTemperature: 24,
            indoorHumidity: 60,
            outdoorTemperature: 18,
            outdoorHumidity: 50
        ),
        weather: weather,
        previousState: nil,
        now: now
    )
    #expect(ventilating.snapshot.weatherAdvisory?.kind == .rainAndWind)
    #expect(ventilating.snapshot.analysis.explanation.contains("nur kippen"))

    let closed = advisor.evaluate(
        snapshot: recommendationTestSnapshot(
            timestamp: now,
            indoorTemperature: 20,
            indoorHumidity: 40,
            outdoorTemperature: 25,
            outdoorHumidity: 70
        ),
        weather: weather,
        previousState: nil,
        now: now
    )
    #expect(closed.snapshot.analysis.recommendation == .closeWindows)
    #expect(closed.snapshot.weatherAdvisory == nil)
}

private func recommendationTestSnapshot(
    timestamp: Date,
    indoorTemperature: Double,
    indoorHumidity: Double,
    outdoorTemperature: Double,
    outdoorHumidity: Double
) -> SensorSnapshot {
    let indoor = ClimateMeasurement(
        temperature: indoorTemperature,
        humidity: indoorHumidity
    )
    let outdoor = ClimateMeasurement(
        temperature: outdoorTemperature,
        humidity: outdoorHumidity
    )
    return SensorSnapshot(
        version: 2,
        timestamp: timestamp,
        source: "Test",
        indoor: indoor,
        outdoor: outdoor,
        indoorRooms: [
            SensorReading(id: "stube", name: "Stube", measurement: indoor, isPrimary: true)
        ],
        outdoorSensors: [
            SensorReading(id: "eve-degree", name: "Eve Degree", measurement: outdoor),
            SensorReading(id: "homepod-terrasse", name: "HomePod Terrasse", measurement: outdoor)
        ]
    )
}

private func recommendationTestWeather(
    now: Date,
    temperatures: [Double],
    humidities: [Double],
    rainChance: Double = 0,
    windSpeed: Double = 5
) -> WeatherSnapshot {
    WeatherSnapshot(
        timestamp: now,
        location: "Zuhause",
        current: WeatherReading(
            timestamp: now,
            temperature: temperatures.first ?? 20,
            humidity: humidities.first ?? 50,
            condition: rainChance > 0 ? "Regen" : "Klar",
            precipitationChance: rainChance,
            windSpeed: windSpeed
        ),
        hourlyForecast: zip(temperatures, humidities).enumerated().map { index, values in
            WeatherReading(
                timestamp: now.addingTimeInterval(Double(index + 1) * 60 * 60),
                temperature: values.0,
                humidity: values.1,
                condition: rainChance > 0 ? "Regen" : "Klar",
                precipitationChance: rainChance,
                windSpeed: windSpeed
            )
        }
    )
}

@Test
func completeCLIRunIncludesWeatherWarningToken() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let runDate = ISO8601DateFormatter().date(from: "2026-08-13T20:15:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    try WeatherSnapshotStore().write(
        recommendationTestWeather(
            now: runDate,
            temperatures: [17, 16],
            humidities: [60, 65],
            rainChance: 70,
            windSpeed: 25
        ),
        to: paths.weatherSnapshotURL
    )
    try RecommendationSnapshotStore().write(
        RecommendationStabilityState(
            samples: [],
            effectiveRecommendation: .ventilate
        ),
        to: paths.recommendationStateURL
    )
    try WindowStateStore(fileURL: paths.windowStateURL).save(
        .waitingForOpening,
        now: runDate
    )

    let output = try ClimateEngineCommand(
        paths: paths,
        now: { runDate }
    ).run(arguments: ["24", "60", "18", "50"])

    #expect(output == "OPEN_WITH_RAIN_AND_WIND_WARNING")
    #expect(FileManager.default.fileExists(atPath: paths.recommendationSnapshotURL.path))
    let saved = try RecommendationSnapshotStore().load(
        from: paths.recommendationSnapshotURL
    )
    #expect(saved.weatherAdvisory?.kind == .rainAndWind)
}

@Test
func weatherWarningIsOnlyEmittedOnceDuringOpenWindow() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let firstDate = ISO8601DateFormatter().date(from: "2026-08-13T20:15:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    try WeatherSnapshotStore().write(
        recommendationTestWeather(
            now: firstDate,
            temperatures: [17, 16],
            humidities: [60, 65],
            rainChance: 70,
            windSpeed: 25
        ),
        to: paths.weatherSnapshotURL
    )
    try RecommendationSnapshotStore().write(
        RecommendationStabilityState(
            samples: [],
            effectiveRecommendation: .ventilate
        ),
        to: paths.recommendationStateURL
    )

    let first = try ClimateEngineCommand(
        paths: paths,
        now: { firstDate }
    ).run(arguments: ["24", "60", "18", "50"])
    let secondDate = firstDate.addingTimeInterval(5 * 60)
    let second = try ClimateEngineCommand(
        paths: paths,
        now: { secondDate }
    ).run(arguments: ["24", "60", "18", "50"])

    #expect(first == "OPEN_WITH_RAIN_AND_WIND_WARNING")
    #expect(second == "NONE")
}

private let additionalSensorTestInput = """
24,1 °C
48 %
23.8 °C
51 %
24.4 °C
0.46
25.2 °C
45 %
25.8 °C
43 %
24.9 °C
47 %
24.6 °C
49 %
26.2 °C
42 %
"""

@Test
func additionalSensorInputParserMapsAllEightSensors() throws {
    let runDate = ISO8601DateFormatter().date(from: "2026-08-15T10:02:00Z")!
    let snapshot = try AdditionalSensorInputParser().parse(
        additionalSensorTestInput,
        now: runDate
    )

    #expect(snapshot.timestamp == runDate)
    #expect(snapshot.sensors.count == 8)
    #expect(snapshot.sensors.map(\.roomName) == [
        "Küche", "Bad Peter", "Schlafzimmer", "Büro Alois", "Sauna", "Büro Peter", "Bad Alois",
        "Dachzimmer"
    ])
    #expect(snapshot.sensors[0].measurement.temperature == 24.1)
    #expect(snapshot.sensors[2].measurement.humidity == 46)
    #expect(snapshot.sensors[3].id == "homepod-buero-alois-rechts")
    #expect(snapshot.sensors[7].id == "dachzimmer-sensor")
    #expect(snapshot.sensors[7].measurement.temperature == 26.2)
}

@Test
func completeAdditionalSensorRunWritesSnapshotAndDailyHistory() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let runDate = ISO8601DateFormatter().date(from: "2026-08-15T10:02:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )

    let output = try ClimateEngineCommand(paths: paths, now: { runDate }).run(
        arguments: ["additional-sensors"],
        standardInput: additionalSensorTestInput
    )

    #expect(output == "ADDITIONAL_SENSORS_SAVED")
    #expect(FileManager.default.fileExists(atPath: paths.additionalSensorSnapshotURL.path))
    let snapshot = try AdditionalSensorSnapshotStore().load(
        from: paths.additionalSensorSnapshotURL
    )
    #expect(snapshot.sensors.count == 8)

    let historyFiles = try FileManager.default.contentsOfDirectory(
        at: paths.additionalSensorHistoryDirectory,
        includingPropertiesForKeys: nil
    )
    #expect(historyFiles.count == 1)
    let historyLines = try String(contentsOf: historyFiles[0], encoding: .utf8)
        .split(whereSeparator: \.isNewline)
    #expect(historyLines.count == 1)
}

@Test
func malformedAdditionalInputDoesNotReplaceExistingSnapshot() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let runDate = ISO8601DateFormatter().date(from: "2026-08-15T10:02:00Z")!
    let paths = ClimateEnginePaths(
        dataDirectory: temporaryRoot.appendingPathComponent("data"),
        stateDirectory: temporaryRoot.appendingPathComponent("state")
    )
    let command = ClimateEngineCommand(paths: paths, now: { runDate })

    _ = try command.run(
        arguments: ["additional-sensors"],
        standardInput: additionalSensorTestInput
    )
    let originalData = try Data(contentsOf: paths.additionalSensorSnapshotURL)

    #expect(throws: (any Error).self) {
        try command.run(
            arguments: ["additional-sensors"],
            standardInput: "24.0\n50"
        )
    }
    #expect(try Data(contentsOf: paths.additionalSensorSnapshotURL) == originalData)
}
