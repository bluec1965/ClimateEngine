import Foundation
import Testing
@testable import ClimateEngine

private let terraceTime = Date(timeIntervalSince1970: 1_789_000_000)

private func terracePayload(
    at date: Date, failed: Set<String> = [], stale: Set<String> = []
) throws -> String {
    let sensors: [[String: Any]] = [
        ("stube", 24.0, 55.0), ("schlafzimmer", 23.0, 50.0),
        ("buero-alois", 24.0, 51.0), ("sauna", 24.0, 52.0),
        ("eve-degree", 18.0, 50.0), ("homepod-terrasse", 20.0, 55.0)
    ].map { id, temperature, humidity in
        var sensor: [String: Any] = [
            "id": id,
            "measuredAt": ISO8601DateFormatter().string(
                from: date.addingTimeInterval(stale.contains(id) ? -600 : 0)
            )
        ]
        if failed.contains(id) {
            sensor["failure"] = "unavailable"
        } else {
            sensor["measurement"] = ["temperature": temperature, "humidity": humidity]
        }
        return sensor
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: [
        "version": 1, "timestamp": ISO8601DateFormatter().string(from: date), "sensors": sensors
    ]), as: UTF8.self)
}

private func withTerracePaths(_ body: (ClimateEnginePaths) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(ClimateEnginePaths(dataDirectory: directory, stateDirectory: directory))
}

@Test func terraceFallbackPreservesSourceAndRecoversWithoutDuplicateSensor() throws {
    try withTerracePaths { paths in
        let run = { (date: Date, failed: Set<String>) in
            try ClimateEngineCommand(paths: paths, now: { date }).run(
                arguments: ["sensor-readings"], standardInput: terracePayload(at: date, failed: failed)
            )
        }
        _ = try run(terraceTime, [])
        _ = try run(terraceTime.addingTimeInterval(300), ["eve-degree"])
        let fallback = try SensorSnapshotLoader().load(from: paths.snapshotURL)
        #expect(fallback.outdoorSensors.map(\.id) == ["homepod-terrasse"])
        #expect(fallback.outdoor.temperature == 20)
        #expect(fallback.acquisition?.unavailableOutdoorIDs == ["eve-degree"])
        #expect(fallback.acquisition?.outdoorSummary.contains("Ersatzbetrieb") == true)
        let recommendation = try RecommendationSnapshotStore().load(from: paths.recommendationSnapshotURL)
        #expect(abs(recommendation.analysis.outdoorTemperature - 20) < 0.001)
        let history = try HistoryReader(directory: paths.historyDirectory).loadToday(now: terraceTime)
        #expect(history.count == 2)
        #expect(history.last?.outdoorSensors.map(\.id) == ["homepod-terrasse"])
        #expect(history.last?.acquisition?.unavailableOutdoorIDs == ["eve-degree"])

        _ = try run(terraceTime.addingTimeInterval(600), [])
        let recovered = try SensorSnapshotLoader().load(from: paths.snapshotURL)
        #expect(Set(recovered.outdoorSensors.map(\.id)) == ["eve-degree", "homepod-terrasse"])
        #expect(recovered.acquisition?.unavailableOutdoorIDs.isEmpty == true)
        let state = try #require(try RecommendationSnapshotStore().loadState(from: paths.recommendationStateURL))
        #expect(state.samples.count == 1)
        #expect(abs(state.samples[0].outdoor.temperature - 19) < 0.001)
    }
}

@Test func bothTerraceSensorsUnavailablePreservesLastMeasurementAndSuppressesEvaluation() throws {
    try withTerracePaths { paths in
        _ = try ClimateEngineCommand(paths: paths, now: { terraceTime }).run(
            arguments: ["sensor-readings"], standardInput: terracePayload(at: terraceTime)
        )
        let original = try Data(contentsOf: paths.snapshotURL)
        let recommendation = try Data(contentsOf: paths.recommendationSnapshotURL)
        let stability = try Data(contentsOf: paths.recommendationStateURL)
        let date = terraceTime.addingTimeInterval(300)
        let command = ClimateEngineCommand(paths: paths, now: { date })
        let result = try command.run(arguments: ["sensor-readings"], standardInput: terracePayload(
            at: date, failed: ["eve-degree", "homepod-terrasse"]
        ))
        #expect(result == "NONE")
        #expect(try command.run(arguments: []) == "NONE")
        #expect(try Data(contentsOf: paths.snapshotURL) == original)
        #expect(try Data(contentsOf: paths.recommendationSnapshotURL) == recommendation)
        #expect(try Data(contentsOf: paths.recommendationStateURL) == stability)
        let status = try #require(try SensorAcquisitionStore().load(from: paths.sensorAcquisitionURL))
        #expect(!status.accepted)
        #expect(status.message.contains("Beide Aussensensoren"))
        #expect(try HistoryReader(directory: paths.historyDirectory).loadToday(now: terraceTime).count == 1)
    }
}

@Test func terraceCanStartWithOnlyEitherOutdoorSensorButRequiresAllIndoorRooms() throws {
    for failedID in ["eve-degree", "homepod-terrasse", "stube"] {
        try withTerracePaths { paths in
            let result = try ClimateEngineCommand(paths: paths, now: { terraceTime }).run(
                arguments: ["sensor-readings"],
                standardInput: terracePayload(at: terraceTime, failed: [failedID])
            )
            if failedID == "stube" {
                #expect(result == "NONE")
                #expect(!FileManager.default.fileExists(atPath: paths.snapshotURL.path))
            } else {
                let snapshot = try SensorSnapshotLoader().load(from: paths.snapshotURL)
                #expect(snapshot.outdoorSensors.count == 1)
                #expect(snapshot.outdoorSensors[0].id != failedID)
            }
        }
    }
}

@Test func terraceRejectsStaleAndMalformedResultsWithoutTreatingThemAsFreshFallback() throws {
    let text = try terracePayload(at: terraceTime)
    var object = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    let sensors = try #require(object["sensors"] as? [[String: Any]])
    object["sensors"] = Array(sensors.dropLast()) + [sensors[0]]
    let duplicate = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    for payload in [duplicate, try terracePayload(at: terraceTime, stale: ["eve-degree"])] {
        try withTerracePaths { paths in
            #expect(throws: (any Error).self) {
                try ClimateEngineCommand(paths: paths, now: { terraceTime }).run(
                    arguments: ["sensor-readings"], standardInput: payload
                )
            }
            #expect(!FileManager.default.fileExists(atPath: paths.snapshotURL.path))
            let status = try SensorAcquisitionStore().load(from: paths.sensorAcquisitionURL)
            #expect(status?.accepted == false)
        }
    }
}

@Test func terraceReplayDoesNotCreateHistoryOrChangeState() throws {
    try withTerracePaths { paths in
        let payload = try terracePayload(at: terraceTime)
        _ = try ClimateEngineCommand(paths: paths, now: { terraceTime }).run(
            arguments: ["sensor-readings"], standardInput: payload
        )
        let state = try Data(contentsOf: paths.recommendationStateURL)
        let replay = try ClimateEngineCommand(paths: paths, now: { terraceTime.addingTimeInterval(60) }).run(
            arguments: ["sensor-readings"], standardInput: payload
        )
        #expect(replay == "NONE")
        #expect(try Data(contentsOf: paths.recommendationStateURL) == state)
        #expect(try HistoryReader(directory: paths.historyDirectory).loadToday(now: terraceTime).count == 1)
    }
}

@Test func ordinaryMissingOutdoorSensorStillFailsCompletenessCheck() throws {
    try withTerracePaths { paths in
        let collection = try SensorCollection.decode(terracePayload(at: terraceTime), now: terraceTime)
        let snapshot = SensorSnapshot(
            version: 2, timestamp: terraceTime, source: "test",
            indoor: collection.indoorRooms[0].measurement, outdoor: collection.outdoorSensors[0].measurement,
            indoorRooms: collection.indoorRooms, outdoorSensors: collection.outdoorSensors
        )
        let result = try SensorInputQualityController(stateURL: paths.sensorInputStateURL).evaluate(
            indoorRooms: collection.indoorRooms,
            outdoorSensors: collection.outdoorSensors.filter { $0.id == "homepod-terrasse" },
            previousSnapshot: snapshot, now: terraceTime.addingTimeInterval(300)
        )
        #expect(!result.isAccepted)
    }
}
