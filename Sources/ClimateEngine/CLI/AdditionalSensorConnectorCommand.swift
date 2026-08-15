import Foundation

struct AdditionalSensorConnectorCommand {
    let paths: ClimateEnginePaths
    let now: () -> Date

    func run(standardInput: String) throws -> String {
        let snapshot = try AdditionalSensorInputParser().parse(
            standardInput,
            now: now()
        )

        try AdditionalSensorSnapshotStore().write(
            snapshot,
            to: paths.additionalSensorSnapshotURL
        )
        try AdditionalSensorHistoryWriter(
            directory: paths.additionalSensorHistoryDirectory
        ).append(snapshot)

        return "ADDITIONAL_SENSORS_SAVED"
    }
}
