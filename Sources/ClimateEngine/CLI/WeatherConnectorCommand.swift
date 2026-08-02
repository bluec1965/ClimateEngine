import Foundation

struct WeatherConnectorCommand {
    let paths: ClimateEnginePaths
    let now: () -> Date

    func run(standardInput: String) throws -> String {
        let executionDate = now()
        let snapshot = try WeatherInputParser().parse(
            standardInput,
            now: executionDate
        )

        try WeatherSnapshotStore().write(snapshot, to: paths.weatherSnapshotURL)
        try WeatherHistoryWriter(directory: paths.weatherHistoryDirectory).append(snapshot)

        return "WEATHER_SAVED"
    }
}
