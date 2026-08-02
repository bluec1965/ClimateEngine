import Foundation

public struct ClimateEnginePaths: Sendable {
    public let dataDirectory: URL
    public let stateDirectory: URL

    public init(
        dataDirectory: URL,
        stateDirectory: URL
    ) {
        self.dataDirectory = dataDirectory
        self.stateDirectory = stateDirectory
    }

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let applicationSupportDirectory = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("ClimateEngine")

        self.init(
            dataDirectory: applicationSupportDirectory,
            stateDirectory: applicationSupportDirectory
        )
    }

    public var snapshotURL: URL {
        dataDirectory.appendingPathComponent("current.json")
    }

    public var stateURL: URL {
        stateDirectory
            .appendingPathComponent("last-summer-night-ventilation-notification.txt")
    }

    public var historyDirectory: URL {
        dataDirectory.appendingPathComponent("history")
    }

    public var windowStateURL: URL {
        dataDirectory.appendingPathComponent("windowState.json")
    }

    public var weatherSnapshotURL: URL {
        dataDirectory
            .appendingPathComponent("weather")
            .appendingPathComponent("current.json")
    }

    public var weatherHistoryDirectory: URL {
        dataDirectory
            .appendingPathComponent("weather")
            .appendingPathComponent("history")
    }

    public static let current = ClimateEnginePaths()
}

public enum CLIPaths {
    public static var snapshotURL: URL { ClimateEnginePaths.current.snapshotURL }
    public static var stateDirectory: URL { ClimateEnginePaths.current.stateDirectory }
    public static var stateURL: URL { ClimateEnginePaths.current.stateURL }
    public static var historyDirectory: URL { ClimateEnginePaths.current.historyDirectory }
    public static var windowStateURL: URL { ClimateEnginePaths.current.windowStateURL }
    public static var weatherSnapshotURL: URL { ClimateEnginePaths.current.weatherSnapshotURL }
    public static var weatherHistoryDirectory: URL { ClimateEnginePaths.current.weatherHistoryDirectory }
}
