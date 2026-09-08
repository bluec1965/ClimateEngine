import Foundation
import Testing
@testable import ClimateEngine

private let fallbackTime = Date(timeIntervalSince1970: 1_789_100_000)

private let fallbackDefinitions: [(room: String, replacement: String, name: String, temperature: Double, humidity: Double)] = [
    ("stube", "homepod-kueche", "HomePod Küche", 24.4, 50),
    ("schlafzimmer", "homepod-schlafzimmer", "HomePod Schlafzimmer", 23.2, 51),
    ("buero-alois", "homepod-buero-alois-rechts", "HomePod Büro Alois Rechts", 23.0, 52),
    ("sauna", "homepod-sauna-links", "HomePod Sauna Links", 24.5, 53),
]

private func indoorFallbackPayload(at date: Date, failed: Set<String>) throws -> String {
    let definitions: [(String, Double, Double)] = [
        ("stube", 24, 55), ("schlafzimmer", 23, 50),
        ("buero-alois", 24, 51), ("sauna", 24, 52),
        ("eve-degree", 18, 50), ("homepod-terrasse", 20, 55),
    ]
    let sensors = definitions.map { id, temperature, humidity -> [String: Any] in
        var sensor: [String: Any] = [
            "id": id,
            "measuredAt": ISO8601DateFormatter().string(from: date),
        ]
        if failed.contains(id) {
            sensor["failure"] = "unavailable"
        } else {
            sensor["measurement"] = ["temperature": temperature, "humidity": humidity]
        }
        return sensor
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: [
        "version": 1,
        "timestamp": ISO8601DateFormatter().string(from: date),
        "sensors": sensors,
    ]), as: UTF8.self)
}

private func seedAdditionalFallbacks(
    paths: ClimateEnginePaths,
    timestamp: Date,
    missing: Set<String> = []
) throws {
    let readings = fallbackDefinitions.compactMap { item -> AdditionalSensorReading? in
        guard !missing.contains(item.replacement) else { return nil }
        return AdditionalSensorReading(
            id: item.replacement,
            name: item.name,
            roomID: item.room,
            roomName: item.room,
            measurement: ClimateMeasurement(temperature: item.temperature, humidity: item.humidity)
        )
    }
    let collected = fallbackDefinitions.map { item in
        CollectedSensor(
            id: item.replacement,
            measuredAt: timestamp,
            measurement: missing.contains(item.replacement)
                ? nil
                : ClimateMeasurement(temperature: item.temperature, humidity: item.humidity),
            failure: missing.contains(item.replacement) ? "unavailable" : nil
        )
    }
    let status = SensorAcquisitionStatus(
        timestamp: timestamp,
        accepted: !readings.isEmpty,
        message: missing.isEmpty ? "Alle Zusatzsensoren aktuell." : "Zusatzsensor fehlt.",
        sensors: collected
    )
    try AdditionalSensorSnapshotStore().write(
        AdditionalSensorSnapshot(
            version: 2,
            timestamp: timestamp,
            sensors: readings,
            acquisition: status
        ),
        to: paths.additionalSensorSnapshotURL
    )
    try SensorAcquisitionStore().write(status, to: paths.additionalSensorAcquisitionURL)
}

private func withIndoorFallbackPaths(_ body: (ClimateEnginePaths) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(ClimateEnginePaths(dataDirectory: directory, stateDirectory: directory))
}

@Test func everyMainIndoorSensorHasABiasCorrectedRoomFallback() throws {
    for item in fallbackDefinitions {
        try withIndoorFallbackPaths { paths in
            try seedAdditionalFallbacks(paths: paths, timestamp: fallbackTime.addingTimeInterval(-120))
            _ = try ClimateEngineCommand(paths: paths, now: { fallbackTime }).run(
                arguments: ["sensor-readings"],
                standardInput: indoorFallbackPayload(at: fallbackTime, failed: [item.room])
            )

            let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
            #expect(snapshot.indoorRooms.count == 4)
            let room = try #require(snapshot.indoorRooms.first(where: { $0.id == item.room }))
            #expect(room.usesFallback)
            #expect(room.effectiveSensorID == item.replacement)
            #expect(room.effectiveSensorName == item.name)
            let status = try #require(snapshot.acquisition)
            #expect(status.accepted)
            #expect(status.indoorFallbacks?.map(\.roomID) == [item.room])
            #expect(status.indoorFallbackSummary?.contains(item.name) == true)
            #expect(try HistoryReader(directory: paths.historyDirectory).loadToday(now: fallbackTime).count == 1)
        }
    }
}

@Test func indoorMainSensorAutomaticallyReturnsAfterFallback() throws {
    try withIndoorFallbackPaths { paths in
        try seedAdditionalFallbacks(paths: paths, timestamp: fallbackTime.addingTimeInterval(-120))
        _ = try ClimateEngineCommand(paths: paths, now: { fallbackTime }).run(
            arguments: ["sensor-readings"],
            standardInput: indoorFallbackPayload(at: fallbackTime, failed: ["stube"])
        )
        let recoveredTime = fallbackTime.addingTimeInterval(300)
        _ = try ClimateEngineCommand(paths: paths, now: { recoveredTime }).run(
            arguments: ["sensor-readings"],
            standardInput: indoorFallbackPayload(at: recoveredTime, failed: [])
        )
        let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
        let stube = try #require(snapshot.indoorRooms.first(where: { $0.id == "stube" }))
        #expect(!stube.usesFallback)
        #expect(stube.effectiveSensorID == "stube")
        #expect(snapshot.acquisition?.indoorFallbacks?.isEmpty != false)
    }
}

@Test func staleOrUnavailableRoomFallbackDoesNotCreateANewMainSnapshot() throws {
    for (age, missing) in [
        (13 * 60.0, Set<String>()),
        (120.0, Set(["homepod-kueche"])),
    ] {
        try withIndoorFallbackPaths { paths in
            try seedAdditionalFallbacks(
                paths: paths,
                timestamp: fallbackTime.addingTimeInterval(-age),
                missing: missing
            )
            let result = try ClimateEngineCommand(paths: paths, now: { fallbackTime }).run(
                arguments: ["sensor-readings"],
                standardInput: indoorFallbackPayload(at: fallbackTime, failed: ["stube"])
            )
            #expect(result == "NONE")
            #expect(!FileManager.default.fileExists(atPath: paths.snapshotURL.path))
        }
    }
}

@Test func roomGroupingDoesNotDuplicateTheActiveFallbackSensor() throws {
    let fallback = SensorReading(
        id: "stube",
        name: "Stube",
        measurement: ClimateMeasurement(temperature: 24, humidity: 55),
        isPrimary: true,
        sourceSensorID: "homepod-kueche",
        sourceSensorName: "HomePod Küche",
        isFallback: true
    )
    let additional = AdditionalSensorReading(
        id: "homepod-kueche",
        name: "HomePod Küche",
        roomID: "stube",
        roomName: "Stube",
        measurement: ClimateMeasurement(temperature: 24.4, humidity: 50)
    )
    let group = try #require(RoomSensorGrouper().groups(
        primaryRooms: [fallback], additionalSensors: [additional]
    ).first)
    #expect(group.sensors.count == 1)
    #expect(group.sensors[0].origin == .fallback)
    #expect(group.biasCorrectedMeasurement == nil)
    #expect(group.isSMSReferenceRoom)
}
