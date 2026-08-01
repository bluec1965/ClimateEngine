import Foundation

public final class WindowStateStore {

    private let fileURL: URL
    private let calendar: Calendar

    public init(
        fileURL: URL,
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.calendar = calendar
    }

    public func load(now: Date = Date()) throws -> WindowState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .waitingForOpening
        }

        let data = try Data(contentsOf: fileURL)
        let persisted = try JSONDecoder().decode(PersistedWindowState.self, from: data)
        return persisted.state
    }

    public func save(
        _ state: WindowState,
        now: Date = Date()
    ) throws {
        let directory = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let persisted = PersistedWindowState(
            state: state,
            day: dayKey(for: now)
        )

        let data = try JSONEncoder().encode(persisted)

        try data.write(
            to: fileURL,
            options: .atomic
        )
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
