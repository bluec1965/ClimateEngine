import Foundation

public struct RoomSensorGrouper {
    private struct Builder {
        let id: String
        let name: String
        var sensors: [RoomSensorObservation]
    }

    public init() {}

    public func groups(
        primaryRooms: [SensorReading],
        additionalSensors: [AdditionalSensorReading]
    ) -> [RoomSensorGroup] {
        var builders = primaryRooms.map { reading in
            Builder(
                id: reading.id,
                name: reading.name,
                sensors: [
                    RoomSensorObservation(
                        id: reading.id,
                        name: reading.name,
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

        return builders.map {
            RoomSensorGroup(id: $0.id, name: $0.name, sensors: $0.sensors)
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
