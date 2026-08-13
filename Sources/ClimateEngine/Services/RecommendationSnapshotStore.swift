import Foundation

public final class RecommendationSnapshotStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func write(_ snapshot: RecommendationSnapshot, to url: URL) throws {
        try write(snapshot, to: url, encoder: encoder)
    }

    public func load(from url: URL) throws -> RecommendationSnapshot {
        try decoder.decode(RecommendationSnapshot.self, from: Data(contentsOf: url))
    }

    public func write(_ state: RecommendationStabilityState, to url: URL) throws {
        try write(state, to: url, encoder: encoder)
    }

    public func loadState(from url: URL) throws -> RecommendationStabilityState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(RecommendationStabilityState.self, from: Data(contentsOf: url))
    }

    private func write<T: Encodable>(_ value: T, to url: URL, encoder: JSONEncoder) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
