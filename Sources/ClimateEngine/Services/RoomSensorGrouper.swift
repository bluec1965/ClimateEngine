import Foundation

public struct RoomSensorGrouper {
    private struct BiasProfile {
        let additionalSensorID: String
        let correction: RoomSensorBiasCorrection
    }

    private struct Builder {
        let id: String
        let name: String
        var sensors: [RoomSensorObservation]
    }

    private static let biasProfiles: [String: BiasProfile] = [
        "stube": BiasProfile(
            additionalSensorID: "homepod-kueche",
            correction: RoomSensorBiasCorrection(
                temperatureAdjustment: -0.403,
                relativeHumidityAdjustment: 5.0625915527344,
                sampleCount: 3_142,
                analysisPeriod: "15.–28. August 2026"
            )
        ),
        "schlafzimmer": BiasProfile(
            additionalSensorID: "homepod-schlafzimmer",
            correction: RoomSensorBiasCorrection(
                temperatureAdjustment: -0.12,
                relativeHumidityAdjustment: 3.5944519042969,
                sampleCount: 3_142,
                analysisPeriod: "15.–28. August 2026"
            )
        ),
        "buero-alois": BiasProfile(
            additionalSensorID: "homepod-buero-alois-rechts",
            correction: RoomSensorBiasCorrection(
                temperatureAdjustment: 0.9,
                relativeHumidityAdjustment: -1,
                sampleCount: 3_142,
                analysisPeriod: "15.–28. August 2026",
                isProvisional: true,
                caveat: "Temperaturabweichung abhängig vom Messbereich (ca. −0,3 bis −1,1 °C)."
            )
        ),
        "sauna": BiasProfile(
            additionalSensorID: "homepod-sauna-links",
            correction: RoomSensorBiasCorrection(
                temperatureAdjustment: -0.5,
                relativeHumidityAdjustment: 1,
                sampleCount: 3_142,
                analysisPeriod: "15.–28. August 2026",
                isProvisional: true,
                caveat: "Feuchteabweichung abhängig von der Temperatur (ca. −4 bis +1 %-Pkt. rF)."
            )
        )
    ]

    public init() {}

    public func groups(
        primaryRooms: [SensorReading],
        additionalSensors: [AdditionalSensorReading],
        includeBiasCorrectedMeasurements: Bool = true
    ) -> [RoomSensorGroup] {
        var builders = primaryRooms.map { reading in
            Builder(
                id: reading.id,
                name: reading.name,
                sensors: [
                    RoomSensorObservation(
                        id: reading.id,
                        name: displayName(forPrimarySensor: reading),
                        measurement: reading.measurement,
                        origin: .mainConnector,
                        isReferenceSensor: reading.isPrimary
                    )
                ]
            )
        }

        for sensor in additionalSensors {
            let room = canonicalRoom(for: sensor)
            let observation = RoomSensorObservation(
                id: sensor.id,
                name: sensor.name,
                measurement: sensor.measurement,
                origin: .additionalConnector
            )

            if let index = builders.firstIndex(where: { $0.id == room.id }) {
                builders[index].sensors.append(observation)
            } else {
                builders.append(
                    Builder(
                        id: room.id,
                        name: room.name,
                        sensors: [observation]
                    )
                )
            }
        }

        return builders.map { builder in
            RoomSensorGroup(
                id: builder.id,
                name: builder.name,
                sensors: builder.sensors,
                biasCorrectedMeasurement: includeBiasCorrectedMeasurements
                    ? biasCorrectedMeasurement(for: builder)
                    : nil
            )
        }
    }

    private func biasCorrectedMeasurement(
        for builder: Builder
    ) -> BiasCorrectedRoomMeasurement? {
        guard let profile = Self.biasProfiles[builder.id],
              let reference = builder.sensors.first(where: {
                  $0.origin == .mainConnector && $0.id == builder.id
              }),
              let additional = builder.sensors.first(where: {
                  $0.origin == .additionalConnector && $0.id == profile.additionalSensorID
              }) else {
            return nil
        }

        let correctedTemperature = additional.measurement.temperature
            + profile.correction.temperatureAdjustment
        let correctedHumidity = min(
            100,
            max(
                0,
                additional.measurement.humidity
                    + profile.correction.relativeHumidityAdjustment
            )
        )

        return BiasCorrectedRoomMeasurement(
            measurement: ClimateMeasurement(
                temperature: (
                    reference.measurement.temperature + correctedTemperature
                ) / 2,
                humidity: (
                    reference.measurement.humidity + correctedHumidity
                ) / 2
            ),
            correction: profile.correction,
            baselineSensorName: reference.name,
            adjustedSensorName: additional.name
        )
    }

    private func displayName(forPrimarySensor sensor: SensorReading) -> String {
        switch sensor.id {
        case "buero-alois":
            return "HomePod Büro Alois Links"
        case "sauna":
            return "HomePod Sauna Rechts"
        default:
            return sensor.name
        }
    }

    private func canonicalRoom(
        for sensor: AdditionalSensorReading
    ) -> (id: String, name: String) {
        switch sensor.id {
        case "homepod-kueche":
            return ("stube", "Stube")
        case "homepod-schlafzimmer":
            return ("schlafzimmer", "Schlafzimmer")
        case "homepod-buero-alois-rechts":
            return ("buero-alois", "Büro Alois")
        case "homepod-sauna-links":
            return ("sauna", "Sauna")
        default:
            return (sensor.roomID, sensor.roomName)
        }
    }
}
