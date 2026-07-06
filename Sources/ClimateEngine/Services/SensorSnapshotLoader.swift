import Foundation

public enum SensorSnapshotLoaderError: Error {
    case fileNotFound(URL)
    case unreadableFile(URL)
    case invalidJSON
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
            throw SensorSnapshotLoaderError.unreadableFile(url)
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
            throw SensorSnapshotLoaderError.invalidJSON
        }
    }
}
