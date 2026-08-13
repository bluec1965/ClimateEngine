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

    public var sensorInputStateURL: URL {
        stateDirectory
            .appendingPathComponent("sensor-input")
            .appendingPathComponent("validation-state.json")
    }

    public var sensorInputHistoryDirectory: URL {
        dataDirectory
            .appendingPathComponent("sensor-input")
            .appendingPathComponent("history")
    }

    public var recommendationStateURL: URL {
        stateDirectory
            .appendingPathComponent("recommendation")
            .appendingPathComponent("stability-state.json")
    }

    public var recommendationSnapshotURL: URL {
        dataDirectory.appendingPathComponent("current-recommendation.json")
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
    public static var sensorInputStateURL: URL { ClimateEnginePaths.current.sensorInputStateURL }
    public static var recommendationStateURL: URL { ClimateEnginePaths.current.recommendationStateURL }
    public static var recommendationSnapshotURL: URL { ClimateEnginePaths.current.recommendationSnapshotURL }
    public static var sensorInputHistoryDirectory: URL {
        ClimateEnginePaths.current.sensorInputHistoryDirectory
    }
}
