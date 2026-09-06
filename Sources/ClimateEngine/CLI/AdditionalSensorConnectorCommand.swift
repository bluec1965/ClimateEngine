import Foundation

struct AdditionalSensorConnectorCommand {
    let paths: ClimateEnginePaths
    let now: () -> Date

    func runCollected(_ input: String) throws -> String {
        let date = now()
        let definitions = AdditionalSensorInputParser.definitions
        let collection: SensorCollection
        do {
            collection = try SensorCollection.decode(input, now: date, expectedIDs: Set(definitions.map(\.id)))
        } catch {
            try SensorAcquisitionStore().write(SensorAcquisitionStatus(
                timestamp: date, accepted: false,
                message: "Zusatzsensorlauf ungültig · keine aktuellen Zusatzsensorwerte.", sensors: []
            ), to: paths.additionalSensorAcquisitionURL)
            throw error
        }
        let previous = try? AdditionalSensorSnapshotStore().load(from: paths.additionalSensorSnapshotURL)
        let previousStatus = try SensorAcquisitionStore().load(from: paths.additionalSensorAcquisitionURL)
        if collection.timestamp <= max(previous?.timestamp ?? .distantPast, previousStatus?.timestamp ?? .distantPast) {
            return "ADDITIONAL_SENSORS_UNCHANGED"
        }
        let readings: [AdditionalSensorReading] = definitions.compactMap { definition in
            guard let measurement = collection.sensors.first(where: { $0.id == definition.id })?.measurement else { return nil }
            return AdditionalSensorReading(id: definition.id, name: definition.name,
                roomID: definition.roomID, roomName: definition.roomName, measurement: measurement)
        }
        let missing = collection.sensors.filter { $0.measurement == nil }
        let message = readings.isEmpty ? "Alle Zusatzsensoren nicht verfügbar."
            : missing.isEmpty ? "Alle Zusatzsensoren aktuell."
            : "Nicht verfügbar: " + missing.map(\.name).joined(separator: ", ")
        let status = collection.status(at: collection.timestamp, accepted: !readings.isEmpty, message: message)
        if !readings.isEmpty {
            let snapshot = AdditionalSensorSnapshot(version: 2, timestamp: collection.timestamp,
                sensors: readings, acquisition: status)
            try AdditionalSensorSnapshotStore().write(snapshot, to: paths.additionalSensorSnapshotURL)
            try AdditionalSensorHistoryWriter(directory: paths.additionalSensorHistoryDirectory).append(snapshot)
        }
        try SensorAcquisitionStore().write(status, to: paths.additionalSensorAcquisitionURL)
        return readings.isEmpty ? "ADDITIONAL_SENSORS_UNAVAILABLE" : "ADDITIONAL_SENSORS_SAVED"
    }

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
