import Foundation

public enum CLIPaths {

    public static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    public static var snapshotURL: URL {
        home
            .appendingPathComponent("Documents")
            .appendingPathComponent("ClimateEngine")
            .appendingPathComponent("current.json")
    }

    public static var stateDirectory: URL {
        home
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("ClimateEngine")
    }

    public static var stateURL: URL {
        stateDirectory
            .appendingPathComponent("last-summer-night-ventilation-notification.txt")
    }
}
