import Foundation

public final class HistoryReader {

    private let directory: URL
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadToday() throws -> [HistoryEntry] {

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let filename = formatter.string(from: Date()) + ".jsonl"

        let fileURL = directory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let text = try String(contentsOf: fileURL, encoding: .utf8)

        return try text
            .split(separator: "\n")
            .map { line in
                try decoder.decode(
                    HistoryEntry.self,
                    from: Data(line.utf8)
                )
            }
    }
}
