import XCTest
@testable import ClimateEngine

final class HeatingRoomPlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func testWeekdayUsesComfortTemperatureWithinWindow() {
        let result = HeatingWeeklySchedule.bueroAloisPrototype.evaluation(
            at: date("2026-09-15T12:00:00Z"),
            calendar: calendar
        )
        XCTAssertEqual(result.period, .comfort)
        XCTAssertEqual(result.targetTemperature, 21.5)
        XCTAssertEqual(result.comfortStartMinute, 360)
        XCTAssertEqual(result.comfortEndMinute, 1320)
    }

    func testWeekendStartsLaterAndEndsLater() {
        let result = HeatingWeeklySchedule.bueroAloisPrototype.evaluation(
            at: date("2026-09-19T07:00:00Z"),
            calendar: calendar
        )
        XCTAssertEqual(result.period, .night)
        XCTAssertEqual(result.targetTemperature, 18.0)
        XCTAssertEqual(result.comfortStartMinute, 450)
        XCTAssertEqual(result.comfortEndMinute, 1380)
    }

    func testWindowOverrideIsRoomSpecific() {
        let state = HeatingRoomOverrideState(openRoomIDs: ["buero-alois"])
        XCTAssertTrue(state.isWindowOpen(roomID: "buero-alois"))
        XCTAssertFalse(state.isWindowOpen(roomID: "sauna"))
    }
}
