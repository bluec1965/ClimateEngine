import Foundation

public enum WeatherSnapshotStoreError: Error, CustomStringConvertible {
    case fileNotFound(URL)
    case unreadableFile(URL, String)
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .fileNotFound(let url):
            return "Wetterdatei nicht gefunden: \(url.path)"
        case .unreadableFile(let url, let cause):
            return "Wetterdatei nicht lesbar (\(url.path)): \(cause)"
        case .invalidJSON(let cause):
            return "Ungültige Wetterdaten: \(cause)"
        }
    }
}

public final class WeatherSnapshotStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func write(_ snapshot: WeatherSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> WeatherSnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WeatherSnapshotStoreError.fileNotFound(url)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw WeatherSnapshotStoreError.unreadableFile(
                url,
                String(reflecting: error)
            )
        }

        do {
            return try decoder.decode(WeatherSnapshot.self, from: data)
        } catch {
            throw WeatherSnapshotStoreError.invalidJSON(String(reflecting: error))
        }
    }
}

public final class WeatherHistoryWriter {
    private let directory: URL
    private let encoder: JSONEncoder

    public init(directory: URL) {
        self.directory = directory
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    public func append(_ snapshot: WeatherSnapshot) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let fileURL = directory.appendingPathComponent(
            formatter.string(from: snapshot.timestamp) + ".jsonl"
        )
        let data = try encoder.encode(snapshot)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.write(Data("\n".utf8))
        } else {
            var output = data
            output.append(Data("\n".utf8))
            try output.write(to: fileURL, options: .atomic)
        }
    }
}
