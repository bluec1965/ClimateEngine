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
    public func todaySummary() throws -> HistorySummary {

        let entries = try loadToday()

        return HistorySummary(
            measurementCount: entries.count,
            firstMeasurement: entries.first?.timestamp,
            lastMeasurement: entries.last?.timestamp
        )
    }
    public func todayEvents() throws -> [HistoryEvent] {
        let entries = try loadToday()

        var events: [HistoryEvent] = []
        var previousRecommendation: String?

        for entry in entries {
            if entry.recommendation != previousRecommendation || entry.notificationSent {
                events.append(
                    HistoryEvent(
                        timestamp: entry.timestamp,
                        recommendation: entry.recommendation,
                        notificationSent: entry.notificationSent
                    )
                )

                previousRecommendation = entry.recommendation
            }
        }

        return events
    }
}
