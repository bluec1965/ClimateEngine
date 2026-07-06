import Foundation

public enum SensorSnapshotLoaderError: Error {
    case fileNotFound
    case invalidJSON
}

public final class SensorSnapshotLoader {

    public init() {}

    public func loadText(from url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SensorSnapshotLoaderError.fileNotFound
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
