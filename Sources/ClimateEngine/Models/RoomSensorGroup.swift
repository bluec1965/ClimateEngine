import Foundation

public enum RoomSensorOrigin: Equatable, Sendable {
    case mainConnector
    case additionalConnector
}

public struct RoomSensorObservation: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let measurement: ClimateMeasurement
    public let origin: RoomSensorOrigin
    public let isReferenceSensor: Bool

    public init(
        id: String,
        name: String,
        measurement: ClimateMeasurement,
        origin: RoomSensorOrigin,
        isReferenceSensor: Bool = false
    ) {
        self.id = id
        self.name = name
        self.measurement = measurement
        self.origin = origin
        self.isReferenceSensor = isReferenceSensor
    }
}

public struct RoomSensorGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let sensors: [RoomSensorObservation]

    public init(
        id: String,
        name: String,
        sensors: [RoomSensorObservation]
    ) {
        self.id = id
        self.name = name
        self.sensors = sensors
    }

    public var isSMSReferenceRoom: Bool {
        sensors.contains(where: \.isReferenceSensor)
    }
}
