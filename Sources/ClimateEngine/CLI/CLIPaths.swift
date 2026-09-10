import Foundation

#if canImport(Darwin)
import Darwin
#endif

public struct ClimateEnginePaths: Sendable {
    public static let dataDirectoryEnvironmentKey = "CLIMATEENGINE_DATA_DIRECTORY"

    public let dataDirectory: URL
    public let stateDirectory: URL

    public init(
        dataDirectory: URL,
        stateDirectory: URL
    ) {
        self.dataDirectory = dataDirectory
        self.stateDirectory = stateDirectory
    }

    public init(homeDirectory: URL) {
        let applicationSupportDirectory = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("ClimateEngine")

        self.init(
            dataDirectory: applicationSupportDirectory,
            stateDirectory: applicationSupportDirectory
        )
    }

    /// Resolves the one data root shared by the LaunchAgent CLI and the macOS app.
    ///
    /// App Sandbox can replace Foundation's process home directory with an app
    /// container. The login account home directory remains stable across both
    /// processes, so it is preferred here. An absolute environment override is
    /// useful for tests and deliberately configured installations.
    public static func shared(
        environment: [String: String],
        accountHomeDirectory: URL? = nil,
        processHomeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> ClimateEnginePaths {
        if let configuredPath = environment[dataDirectoryEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           configuredPath.hasPrefix("/") {
            let directory = URL(
                fileURLWithPath: configuredPath,
                isDirectory: true
            ).standardizedFileURL
            return ClimateEnginePaths(
                dataDirectory: directory,
                stateDirectory: directory
            )
        }

        return ClimateEnginePaths(
            homeDirectory: accountHomeDirectory
                ?? loginAccountHomeDirectory
                ?? processHomeDirectory
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

    public var additionalSensorSnapshotURL: URL {
        dataDirectory
            .appendingPathComponent("additional-sensors")
            .appendingPathComponent("current.json")
    }

    public var additionalSensorHistoryDirectory: URL {
        dataDirectory
            .appendingPathComponent("additional-sensors")
            .appendingPathComponent("history")
    }

    public var sensorInputStateURL: URL {
        stateDirectory
            .appendingPathComponent("sensor-input")
            .appendingPathComponent("validation-state.json")
    }

    public var sensorAcquisitionURL: URL {
        dataDirectory.appendingPathComponent("sensor-input/current-status.json")
    }

    public var additionalSensorAcquisitionURL: URL {
        dataDirectory.appendingPathComponent("additional-sensors/current-status.json")
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

    public var operatingModeURL: URL {
        stateDirectory.appendingPathComponent("operating-mode.json")
    }

    public var ventilationSessionURL: URL {
        stateDirectory.appendingPathComponent("ventilation-session.json")
    }

    public var seasonalRecommendationSnapshotURL: URL {
        dataDirectory
            .appendingPathComponent("seasonal-recommendation")
            .appendingPathComponent("current.json")
    }

    public var seasonalRecommendationHistoryDirectory: URL {
        dataDirectory
            .appendingPathComponent("seasonal-recommendation")
            .appendingPathComponent("history")
    }

    public static let current = ClimateEnginePaths.shared(
        environment: ProcessInfo.processInfo.environment
    )

    private static var loginAccountHomeDirectory: URL? {
        #if canImport(Darwin)
        guard let passwordEntry = getpwuid(getuid()),
              let homePath = passwordEntry.pointee.pw_dir else {
            return nil
        }

        return URL(
            fileURLWithPath: String(cString: homePath),
            isDirectory: true
        ).standardizedFileURL
        #else
        return nil
        #endif
    }
}

public enum CLIPaths {
    public static var snapshotURL: URL { ClimateEnginePaths.current.snapshotURL }
    public static var stateDirectory: URL { ClimateEnginePaths.current.stateDirectory }
    public static var stateURL: URL { ClimateEnginePaths.current.stateURL }
    public static var historyDirectory: URL { ClimateEnginePaths.current.historyDirectory }
    public static var windowStateURL: URL { ClimateEnginePaths.current.windowStateURL }
    public static var weatherSnapshotURL: URL { ClimateEnginePaths.current.weatherSnapshotURL }
    public static var weatherHistoryDirectory: URL { ClimateEnginePaths.current.weatherHistoryDirectory }
    public static var additionalSensorSnapshotURL: URL {
        ClimateEnginePaths.current.additionalSensorSnapshotURL
    }
    public static var additionalSensorHistoryDirectory: URL {
        ClimateEnginePaths.current.additionalSensorHistoryDirectory
    }
    public static var sensorInputStateURL: URL { ClimateEnginePaths.current.sensorInputStateURL }
    public static var recommendationStateURL: URL { ClimateEnginePaths.current.recommendationStateURL }
    public static var recommendationSnapshotURL: URL { ClimateEnginePaths.current.recommendationSnapshotURL }
    public static var operatingModeURL: URL { ClimateEnginePaths.current.operatingModeURL }
    public static var seasonalRecommendationSnapshotURL: URL {
        ClimateEnginePaths.current.seasonalRecommendationSnapshotURL
    }
    public static var seasonalRecommendationHistoryDirectory: URL {
        ClimateEnginePaths.current.seasonalRecommendationHistoryDirectory
    }
    public static var sensorInputHistoryDirectory: URL {
        ClimateEnginePaths.current.sensorInputHistoryDirectory
    }
}
