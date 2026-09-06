import Foundation
import Testing
@testable import ClimateEngine

private let additionalTime = Date(timeIntervalSince1970: 1_789_000_000)

private func additionalPayload(_ date: Date, failed: Set<String> = []) throws -> String {
    let sensors = AdditionalSensorInputParser.definitions.map { definition -> [String: Any] in
        var value: [String: Any] = ["id": definition.id, "measuredAt": ISO8601DateFormatter().string(from: date)]
        if failed.contains(definition.id) { value["failure"] = "unavailable" }
        else { value["measurement"] = ["temperature": 24.0, "humidity": 50.0] }
        return value
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: [
        "version": 1, "timestamp": ISO8601DateFormatter().string(from: date), "sensors": sensors
    ]), as: UTF8.self)
}

private func additionalTestPaths(_ test: (ClimateEnginePaths) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try test(ClimateEnginePaths(dataDirectory: root, stateDirectory: root))
}

@Test func additionalFailureKeepsSevenRealSensorsAndNoBedroomBias() throws {
    try additionalTestPaths { paths in
        let command = ClimateEngineCommand(paths: paths, now: { additionalTime })
        #expect(try command.run(arguments: ["additional-readings"], standardInput:
            additionalPayload(additionalTime, failed: ["homepod-schlafzimmer"])) == "ADDITIONAL_SENSORS_SAVED")
        let snapshot = try AdditionalSensorSnapshotStore().load(from: paths.additionalSensorSnapshotURL)
        #expect(snapshot.sensors.count == 7)
        #expect(!snapshot.sensors.contains { $0.id == "homepod-schlafzimmer" })
        #expect(snapshot.availabilityMessage(status: nil, now: additionalTime)?.contains("HomePod Schlafzimmer") == true)
        #expect(snapshot.currentSensors(status: nil, now: additionalTime).count == 7)
        let groups = RoomSensorGrouper().groups(primaryRooms: [SensorReading(id: "schlafzimmer", name: "Schlafzimmer",
            measurement: ClimateMeasurement(temperature: 24, humidity: 50), isPrimary: false)], additionalSensors: snapshot.sensors)
        #expect(groups.first { $0.id == "schlafzimmer" }?.biasCorrectedMeasurement == nil)
        #expect(try AdditionalSensorHistoryReader(directory: paths.additionalSensorHistoryDirectory).loadToday(now: additionalTime).count == 1)
        #expect(!FileManager.default.fileExists(atPath: paths.snapshotURL.path))
        #expect(!FileManager.default.fileExists(atPath: paths.windowStateURL.path))
    }
}

@Test func additionalRecoveryAndReplayAreSafe() throws {
    try additionalTestPaths { paths in
        _ = try ClimateEngineCommand(paths: paths, now: { additionalTime }).run(arguments: ["additional-readings"],
            standardInput: additionalPayload(additionalTime, failed: ["homepod-schlafzimmer"]))
        let next = additionalTime.addingTimeInterval(300)
        let input = try additionalPayload(next)
        let command = ClimateEngineCommand(paths: paths, now: { next })
        _ = try command.run(arguments: ["additional-readings"], standardInput: input)
        #expect(try command.run(arguments: ["additional-readings"], standardInput: input) == "ADDITIONAL_SENSORS_UNCHANGED")
        let snapshot = try AdditionalSensorSnapshotStore().load(from: paths.additionalSensorSnapshotURL)
        #expect(snapshot.sensors.count == 8)
        #expect(snapshot.availabilityMessage(status: nil, now: next) == nil)
        #expect(try AdditionalSensorHistoryReader(directory: paths.additionalSensorHistoryDirectory).loadToday(now: next).count == 2)
    }
}

@Test func allAdditionalFailuresKeepHistoryButHideOldValues() throws {
    try additionalTestPaths { paths in
        _ = try ClimateEngineCommand(paths: paths, now: { additionalTime }).run(arguments: ["additional-readings"], standardInput: additionalPayload(additionalTime))
        let next = additionalTime.addingTimeInterval(300)
        _ = try ClimateEngineCommand(paths: paths, now: { next }).run(arguments: ["additional-readings"], standardInput:
            additionalPayload(next, failed: Set(AdditionalSensorInputParser.definitions.map(\.id))))
        let snapshot = try AdditionalSensorSnapshotStore().load(from: paths.additionalSensorSnapshotURL)
        let status = try SensorAcquisitionStore().load(from: paths.additionalSensorAcquisitionURL)
        #expect(snapshot.timestamp == additionalTime)
        #expect(snapshot.currentSensors(status: status, now: next).isEmpty)
        #expect(snapshot.availabilityMessage(status: status, now: next) == "Alle Zusatzsensoren nicht verfügbar.")
        #expect(try AdditionalSensorHistoryReader(directory: paths.additionalSensorHistoryDirectory).loadToday(now: next).count == 1)
    }
}

@Test func invalidAndStaleAdditionalPayloadsNeverEnterHistory() throws {
    try additionalTestPaths { paths in
        let command = ClimateEngineCommand(paths: paths, now: { additionalTime })
        for payload in ["{}", try additionalPayload(additionalTime.addingTimeInterval(-600))] {
            #expect(throws: (any Error).self) {
                try command.run(arguments: ["additional-readings"], standardInput: payload)
            }
        }
        #expect(!FileManager.default.fileExists(atPath: paths.additionalSensorSnapshotURL.path))
        #expect(try SensorAcquisitionStore().load(from: paths.additionalSensorAcquisitionURL)?.accepted == false)
    }
}

@Test func additionalLegacyCompatibilityAndStaleness() throws {
    let snapshot = AdditionalSensorSnapshot(timestamp: additionalTime, sensors: [])
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    #expect(!String(decoding: data, as: UTF8.self).contains("acquisition"))
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    #expect(try decoder.decode(AdditionalSensorSnapshot.self, from: data).acquisition == nil)
    #expect(snapshot.availabilityMessage(status: nil, now: additionalTime.addingTimeInterval(721))?.contains("veraltet") == true)
}
