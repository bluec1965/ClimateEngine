import Foundation

public struct HeatingThermostatSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let roomID: String
    public let roomName: String
    public let temperature: Double?
    public let currentStatus: Int?
    public let available: Bool
    public let error: String?

    public init(
        version: Int = 1,
        timestamp: Date,
        roomID: String = "buero-alois",
        roomName: String = "Büro Alois",
        temperature: Double?,
        currentStatus: Int?,
        available: Bool,
        error: String? = nil
    ) {
        self.version = version
        self.timestamp = timestamp
        self.roomID = roomID
        self.roomName = roomName
        self.temperature = temperature
        self.currentStatus = currentStatus
        self.available = available
        self.error = error
    }

    public func isCurrent(at date: Date = Date(), maximumAge: TimeInterval = 12 * 60) -> Bool {
        available && abs(date.timeIntervalSince(timestamp)) <= maximumAge
    }
}

public final class HeatingThermostatSnapshotStore {
    private let decoder: JSONDecoder

    public init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(from url: URL) throws -> HeatingThermostatSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(HeatingThermostatSnapshot.self, from: Data(contentsOf: url))
    }
}

public struct HeatingVentilationControl: Codable, Equatable, Sendable {
    public let version: Int
    public let suspended: Bool
    public let updatedAt: Date
    public let error: String?

    public init(version: Int = 1, suspended: Bool, updatedAt: Date = Date(), error: String? = nil) {
        self.version = version
        self.suspended = suspended
        self.updatedAt = updatedAt
        self.error = error
    }
}

public final class HeatingVentilationControlStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(from url: URL) throws -> HeatingVentilationControl? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(HeatingVentilationControl.self, from: Data(contentsOf: url))
    }

    public func write(_ state: HeatingVentilationControl, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
