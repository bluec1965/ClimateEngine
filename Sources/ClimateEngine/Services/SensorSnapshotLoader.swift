import Foundation

public enum SensorSnapshotLoaderError: Error, CustomStringConvertible {
    case fileNotFound(URL)
    case unreadableFile(URL, String)
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .fileNotFound(let url):
            return "Sensordatei nicht gefunden: \(url.path)"
        case .unreadableFile(let url, let cause):
            return "Sensordatei nicht lesbar (\(url.path)): \(cause)"
        case .invalidJSON(let cause):
            return "Ungültige Sensordaten: \(cause)"
        }
    }
}

public final class SensorSnapshotLoader {

    public init() {}

    public func loadText(from url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SensorSnapshotLoaderError.fileNotFound(url)
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw SensorSnapshotLoaderError.unreadableFile(
                url,
                String(reflecting: error)
            )
        }
    }
    public func load(from url: URL) throws -> SensorSnapshot {

        let text = try loadText(from: url)
        let raw = try decode(text)

        return try raw.toSensorSnapshot()
    }

    func decode(_ text: String) throws -> RawSensorSnapshot {
        let data = Data(text.utf8)
        let decoder = JSONDecoder()

        do {
            return try decoder.decode(RawSensorSnapshot.self, from: data)
        } catch {
            throw SensorSnapshotLoaderError.invalidJSON(
                String(reflecting: error)
            )
        }
    }
}
