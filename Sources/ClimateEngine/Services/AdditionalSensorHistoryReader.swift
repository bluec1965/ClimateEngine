import Foundation

public struct AdditionalSensorHistoryReadResult {
    public let timestamps: [Date]
    public let skippedLineCount: Int

    public init(timestamps: [Date], skippedLineCount: Int) {
        self.timestamps = timestamps
        self.skippedLineCount = skippedLineCount
    }
}

public final class AdditionalSensorHistoryReader {
    private struct TimestampedEntry: Decodable {
        let timestamp: Date
    }

    private let directory: URL
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func loadToday(now: Date = Date()) throws -> [Date] {
        try loadTodayWithDiagnostics(now: now).timestamps
    }

    public func loadTodayWithDiagnostics(
        now: Date = Date()
    ) throws -> AdditionalSensorHistoryReadResult {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let fileURL = directory.appendingPathComponent(
            formatter.string(from: now) + ".jsonl"
        )

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AdditionalSensorHistoryReadResult(
                timestamps: [],
                skippedLineCount: 0
            )
        }

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        var timestamps: [Date] = []
        var skippedLineCount = 0

        for line in text.split(whereSeparator: \.isNewline) {
            do {
                let entry = try decoder.decode(
                    TimestampedEntry.self,
                    from: Data(line.utf8)
                )
                timestamps.append(entry.timestamp)
            } catch {
                // A concurrent append or an older damaged line must not hide
                // the remaining valid additional-sensor measurements.
                skippedLineCount += 1
            }
        }

        timestamps.sort()
        return AdditionalSensorHistoryReadResult(
            timestamps: timestamps,
            skippedLineCount: skippedLineCount
        )
    }

    public func todaySummary(now: Date = Date()) throws -> HistorySummary {
        summary(from: try loadToday(now: now))
    }

    public func summary(from timestamps: [Date]) -> HistorySummary {
        HistorySummary(
            measurementCount: timestamps.count,
            firstMeasurement: timestamps.first,
            lastMeasurement: timestamps.last
        )
    }
}
