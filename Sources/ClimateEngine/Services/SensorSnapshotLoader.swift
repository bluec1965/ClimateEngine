import Foundation

public enum SensorSnapshotLoaderError: Error {
    case fileNotFound(URL)
    case unreadableFile(URL)
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
}
