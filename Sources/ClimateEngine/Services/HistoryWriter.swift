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

        var output = try encoder.encode(entry)
        output.append(Data("\n".utf8))

        if FileManager.default.fileExists(atPath: fileURL.path) {

            let handle = try FileHandle(forWritingTo: fileURL)
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
            try output.write(to: fileURL, options: .atomic)
        }
    }
}
