import Foundation

public struct HistoryReadResult {
    public let entries: [HistoryEntry]
    public let skippedLineCount: Int
}

public final class HistoryReader {

    private let directory: URL
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadToday(now: Date = Date()) throws -> [HistoryEntry] {
        try loadTodayWithDiagnostics(now: now).entries
    }

    public func loadTodayWithDiagnostics(now: Date = Date()) throws -> HistoryReadResult {

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let filename = formatter.string(from: now) + ".jsonl"

        let fileURL = directory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return HistoryReadResult(entries: [], skippedLineCount: 0)
        }

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        var entries: [HistoryEntry] = []
        var skippedLineCount = 0

        for line in text.split(whereSeparator: \.isNewline) {
            do {
                entries.append(try decoder.decode(
                    HistoryEntry.self,
                    from: Data(line.utf8)
                ))
            } catch {
                // A process may observe an incomplete final append, and older
                // versions may have left a malformed record behind. One bad
                // JSONL record must not hide every valid measurement of the day.
                skippedLineCount += 1
            }
        }

        entries.sort { $0.timestamp < $1.timestamp }
        return HistoryReadResult(
            entries: entries,
            skippedLineCount: skippedLineCount
        )
    }

    public func todaySummary(now: Date = Date()) throws -> HistorySummary {
        summary(from: try loadToday(now: now))
    }

    public func summary(from entries: [HistoryEntry]) -> HistorySummary {
        return HistorySummary(
            measurementCount: entries.count,
            firstMeasurement: entries.first?.timestamp,
            lastMeasurement: entries.last?.timestamp
        )
    }

    public func todayEvents(now: Date = Date()) throws -> [HistoryEvent] {
        events(from: try loadToday(now: now))
    }

    public func events(from entries: [HistoryEntry]) -> [HistoryEvent] {
        var events: [HistoryEvent] = []
        var previousRecommendation: String?

        for entry in entries {
            if entry.recommendation != previousRecommendation || entry.notificationSent {
                events.append(
                    HistoryEvent(
                        timestamp: entry.timestamp,
                        recommendation: entry.recommendation,
                        notificationSent: entry.notificationSent,
                        explanation: entry.explanation,
                    )
                )

                previousRecommendation = entry.recommendation
            }
        }

        return events
    }
}
