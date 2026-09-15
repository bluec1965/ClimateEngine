import Foundation

public enum HeatingSchedulePeriod: String, Codable, Equatable, Sendable {
    case comfort
    case night
}

public struct HeatingScheduleEvaluation: Equatable, Sendable {
    public let period: HeatingSchedulePeriod
    public let targetTemperature: Double
    public let comfortStartMinute: Int
    public let comfortEndMinute: Int

    public init(
        period: HeatingSchedulePeriod,
        targetTemperature: Double,
        comfortStartMinute: Int,
        comfortEndMinute: Int
    ) {
        self.period = period
        self.targetTemperature = targetTemperature
        self.comfortStartMinute = comfortStartMinute
        self.comfortEndMinute = comfortEndMinute
    }
}

public struct HeatingWeeklySchedule: Codable, Equatable, Sendable {
    public let comfortTemperature: Double
    public let nightTemperature: Double
    public let weekdayComfortStartMinute: Int
    public let weekdayComfortEndMinute: Int
    public let weekendComfortStartMinute: Int
    public let weekendComfortEndMinute: Int

    public init(
        comfortTemperature: Double,
        nightTemperature: Double,
        weekdayComfortStartMinute: Int,
        weekdayComfortEndMinute: Int,
        weekendComfortStartMinute: Int,
        weekendComfortEndMinute: Int
    ) {
        self.comfortTemperature = comfortTemperature
        self.nightTemperature = nightTemperature
        self.weekdayComfortStartMinute = weekdayComfortStartMinute
        self.weekdayComfortEndMinute = weekdayComfortEndMinute
        self.weekendComfortStartMinute = weekendComfortStartMinute
        self.weekendComfortEndMinute = weekendComfortEndMinute
    }

    public static let bueroAloisPrototype = HeatingWeeklySchedule(
        comfortTemperature: 21.5,
        nightTemperature: 18.0,
        weekdayComfortStartMinute: 6 * 60,
        weekdayComfortEndMinute: 22 * 60,
        weekendComfortStartMinute: 7 * 60 + 30,
        weekendComfortEndMinute: 23 * 60
    )

    public func evaluation(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> HeatingScheduleEvaluation {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let start = isWeekend ? weekendComfortStartMinute : weekdayComfortStartMinute
        let end = isWeekend ? weekendComfortEndMinute : weekdayComfortEndMinute
        let minute = calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
        let period: HeatingSchedulePeriod = (start..<end).contains(minute) ? .comfort : .night
        return HeatingScheduleEvaluation(
            period: period,
            targetTemperature: period == .comfort ? comfortTemperature : nightTemperature,
            comfortStartMinute: start,
            comfortEndMinute: end
        )
    }
}

public struct HeatingRoomOverrideState: Codable, Equatable, Sendable {
    public let version: Int
    public let openRoomIDs: [String]
    public let updatedAt: Date

    public init(version: Int = 1, openRoomIDs: [String], updatedAt: Date = Date()) {
        self.version = version
        self.openRoomIDs = openRoomIDs
        self.updatedAt = updatedAt
    }

    public static func empty(at date: Date = Date()) -> HeatingRoomOverrideState {
        HeatingRoomOverrideState(openRoomIDs: [], updatedAt: date)
    }

    public func isWindowOpen(roomID: String) -> Bool {
        openRoomIDs.contains(roomID)
    }
}

public final class HeatingRoomOverrideStore {
    private let decoder: JSONDecoder

    public init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(from url: URL) throws -> HeatingRoomOverrideState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(HeatingRoomOverrideState.self, from: Data(contentsOf: url))
    }
}
