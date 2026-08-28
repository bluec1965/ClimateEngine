import Foundation

public final class OperatingModeStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(from url: URL, now: Date = Date()) throws -> OperatingModeState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .defaultState(now: now)
        }
        return try decoder.decode(OperatingModeState.self, from: Data(contentsOf: url))
    }

    public func write(_ state: OperatingModeState, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
