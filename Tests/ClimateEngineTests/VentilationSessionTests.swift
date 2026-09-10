import Foundation
import Testing
@testable import ClimateEngine

@Test func ventilationSessionStorePersistsActivityAndAutomaticExpiry() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("ventilation-session.json")
    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let session = VentilationSession.start(at: now)
    try VentilationSessionStore().write(session, to: url)
    let storedSession = try VentilationSessionStore().load(from: url)
    let loaded = try #require(storedSession)
    #expect(loaded.isActive(at: now.addingTimeInterval(599)))
    #expect(!loaded.isActive(at: now.addingTimeInterval(600)))
    #expect(loaded.remainingSeconds(at: now.addingTimeInterval(541)) == 59)
}

@Test func activeVentilationAcceptsExpectedRapidCooling() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let previousIndoor = SensorReading(id: "stube", name: "Stube", measurement: .init(temperature: 23.5, humidity: 55), isPrimary: true)
    let currentIndoor = SensorReading(id: "stube", name: "Stube", measurement: .init(temperature: 21.8, humidity: 44), isPrimary: true)
    let outdoor = SensorReading(id: "eve-degree", name: "Eve Degree", measurement: .init(temperature: 12, humidity: 60), isPrimary: true)
    let previous = SensorSnapshot(
        version: 2, timestamp: now, source: "test",
        indoor: previousIndoor.measurement, outdoor: outdoor.measurement,
        indoorRooms: [previousIndoor], outdoorSensors: [outdoor]
    )

    let normal = try SensorInputQualityController(stateURL: directory.appendingPathComponent("normal.json")).evaluate(
        indoorRooms: [currentIndoor], outdoorSensors: [outdoor], previousSnapshot: previous,
        now: now.addingTimeInterval(300)
    )
    #expect(!normal.isAccepted)

    let ventilating = try SensorInputQualityController(stateURL: directory.appendingPathComponent("ventilating.json")).evaluate(
        indoorRooms: [currentIndoor], outdoorSensors: [outdoor], previousSnapshot: previous,
        now: now.addingTimeInterval(300), ventilationSessionActive: true
    )
    #expect(ventilating.isAccepted)
    #expect(ventilating.reason.contains("aktiver Stosslüftung"))
}

@Test func activeVentilationDoesNotBypassUnexpectedHeatingJump() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let previousIndoor = SensorReading(id: "stube", name: "Stube", measurement: .init(temperature: 22, humidity: 50), isPrimary: true)
    let currentIndoor = SensorReading(id: "stube", name: "Stube", measurement: .init(temperature: 24, humidity: 50), isPrimary: true)
    let outdoor = SensorReading(id: "eve-degree", name: "Eve Degree", measurement: .init(temperature: 12, humidity: 60), isPrimary: true)
    let previous = SensorSnapshot(
        version: 2, timestamp: now, source: "test",
        indoor: previousIndoor.measurement, outdoor: outdoor.measurement,
        indoorRooms: [previousIndoor], outdoorSensors: [outdoor]
    )
    let result = try SensorInputQualityController(stateURL: directory.appendingPathComponent("state.json")).evaluate(
        indoorRooms: [currentIndoor], outdoorSensors: [outdoor], previousSnapshot: previous,
        now: now.addingTimeInterval(300), ventilationSessionActive: true
    )
    #expect(!result.isAccepted)
}
