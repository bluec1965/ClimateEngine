import Foundation

struct IndoorSensorFallbackResolver {
    struct Definition {
        let roomID: String
        let roomName: String
        let mainSensorName: String
        let replacementSensorID: String
        let replacementSensorName: String
        let temperatureAdjustment: Double
        let humidityAdjustment: Double
    }

    struct Result {
        let rooms: [SensorReading]
        let fallbacks: [IndoorSensorFallbackUsage]
        let unresolved: [CollectedSensor]
    }

    static let definitions: [Definition] = [
        Definition(
            roomID: "stube", roomName: "Stube", mainSensorName: "Stube",
            replacementSensorID: "homepod-kueche", replacementSensorName: "HomePod Küche",
            temperatureAdjustment: -0.403, humidityAdjustment: 5.0625915527344
        ),
        Definition(
            roomID: "schlafzimmer", roomName: "Schlafzimmer", mainSensorName: "Schlafzimmer",
            replacementSensorID: "homepod-schlafzimmer", replacementSensorName: "HomePod Schlafzimmer",
            temperatureAdjustment: -0.12, humidityAdjustment: 3.5944519042969
        ),
        Definition(
            roomID: "buero-alois", roomName: "Büro Alois", mainSensorName: "HomePod Büro Alois Links",
            replacementSensorID: "homepod-buero-alois-rechts", replacementSensorName: "HomePod Büro Alois Rechts",
            temperatureAdjustment: 0.9, humidityAdjustment: -1
        ),
        Definition(
            roomID: "sauna", roomName: "Sauna", mainSensorName: "HomePod Sauna Rechts",
            replacementSensorID: "homepod-sauna-links", replacementSensorName: "HomePod Sauna Links",
            temperatureAdjustment: -0.5, humidityAdjustment: 1
        )
    ]

    let paths: ClimateEnginePaths

    func resolve(collection: SensorCollection, now: Date) -> Result {
        let additionalSnapshot = try? AdditionalSensorSnapshotStore().load(
            from: paths.additionalSensorSnapshotURL
        )
        let additionalStatus = try? SensorAcquisitionStore().load(
            from: paths.additionalSensorAcquisitionURL
        )
        let currentAdditional = additionalSnapshot?.currentSensors(
            status: additionalStatus ?? nil,
            now: now
        ) ?? []
        let statusSensors = (additionalStatus ?? nil)?.sensors ?? additionalSnapshot?.acquisition?.sensors ?? []

        var rooms: [SensorReading] = []
        var fallbacks: [IndoorSensorFallbackUsage] = []
        var unresolved: [CollectedSensor] = []

        for definition in Self.definitions {
            guard let main = collection.sensors.first(where: { $0.id == definition.roomID }) else {
                continue
            }
            if let measurement = main.measurement {
                rooms.append(SensorReading(
                    id: definition.roomID,
                    name: definition.roomName,
                    measurement: measurement,
                    isPrimary: definition.roomID == "stube",
                    sourceSensorID: definition.roomID,
                    sourceSensorName: definition.mainSensorName
                ))
                continue
            }
            guard let replacement = currentAdditional.first(where: {
                $0.id == definition.replacementSensorID
            }) else {
                unresolved.append(main)
                continue
            }
            let corrected = ClimateMeasurement(
                temperature: replacement.measurement.temperature + definition.temperatureAdjustment,
                humidity: min(100, max(0,
                    replacement.measurement.humidity + definition.humidityAdjustment
                ))
            )
            rooms.append(SensorReading(
                id: definition.roomID,
                name: definition.roomName,
                measurement: corrected,
                isPrimary: definition.roomID == "stube",
                sourceSensorID: replacement.id,
                sourceSensorName: replacement.name,
                isFallback: true
            ))
            let measuredAt = statusSensors.first(where: {
                $0.id == definition.replacementSensorID && $0.measurement != nil
            })?.measuredAt ?? additionalSnapshot?.timestamp ?? now
            fallbacks.append(IndoorSensorFallbackUsage(
                roomID: definition.roomID,
                roomName: definition.roomName,
                unavailableSensorID: definition.roomID,
                unavailableSensorName: definition.mainSensorName,
                activeSensorID: replacement.id,
                activeSensorName: replacement.name,
                measuredAt: measuredAt,
                biasCorrectionApplied: true
            ))
        }
        return Result(rooms: rooms, fallbacks: fallbacks, unresolved: unresolved)
    }
}
