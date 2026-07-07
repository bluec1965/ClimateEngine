import Foundation

public final class NotificationState {

    private let stateURL: URL

    public init(stateURL: URL = CLIPaths.stateURL) {
        self.stateURL = stateURL
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    public func alreadyNotifiedToday() -> Bool {

        guard let content = try? String(contentsOf: stateURL,
                                        encoding: .utf8) else {
            return false
        }

        return content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            == todayKey()
    }

    public func markNotifiedToday() throws {

        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try todayKey().write(
            to: stateURL,
            atomically: true,
            encoding: .utf8
        )
    }
}
