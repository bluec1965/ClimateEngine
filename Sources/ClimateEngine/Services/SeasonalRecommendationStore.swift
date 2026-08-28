import Foundation

public final class SeasonalRecommendationStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func write(_ snapshot: SeasonalRecommendationSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> SeasonalRecommendationSnapshot {
        try decoder.decode(
            SeasonalRecommendationSnapshot.self,
            from: Data(contentsOf: url)
        )
    }
}

public final class SeasonalRecommendationHistoryWriter {
    private let directory: URL
    private let encoder: JSONEncoder

    public init(directory: URL) {
        self.directory = directory
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    public func append(_ snapshot: SeasonalRecommendationSnapshot) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let url = directory.appendingPathComponent(
            formatter.string(from: snapshot.sensorTimestamp) + ".jsonl"
        )
        var output = try encoder.encode(snapshot)
        output.append(Data("\n".utf8))

        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            if #available(macOS 10.15.4, *) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: output)
                try handle.synchronize()
            } else {
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(output)
                handle.synchronizeFile()
            }
        } else {
            try output.write(to: url, options: .atomic)
        }
    }
}
