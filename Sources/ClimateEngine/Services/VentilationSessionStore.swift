import Foundation

public final class VentilationSessionStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(from url: URL) throws -> VentilationSession? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(
            VentilationSession.self,
            from: Data(contentsOf: url)
        )
    }

    public func write(_ session: VentilationSession, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(session).write(to: url, options: .atomic)
    }
}
