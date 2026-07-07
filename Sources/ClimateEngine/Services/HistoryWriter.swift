import Foundation

public final class HistoryWriter {

    private let directory: URL
    private let encoder: JSONEncoder

    public init(directory: URL) {
        self.directory = directory

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func append(_ entry: HistoryEntry) throws {

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let filename = formatter.string(from: entry.timestamp) + ".jsonl"

        let fileURL = directory.appendingPathComponent(filename)

        let data = try encoder.encode(entry)

        if FileManager.default.fileExists(atPath: fileURL.path) {

            let handle = try FileHandle(forWritingTo: fileURL)
            defer { handle.closeFile() }

            handle.seekToEndOfFile()

            handle.write(data)
            handle.write(Data("\n".utf8))

        } else {

            var output = Data()
            output.append(data)
            output.append(Data("\n".utf8))

            try output.write(to: fileURL)
        }
    }
}
