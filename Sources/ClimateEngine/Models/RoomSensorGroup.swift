import Foundation

public enum RoomSensorOrigin: Equatable, Sendable {
    case mainConnector
    case additionalConnector
    case fallback
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

public struct RoomSensorBiasCorrection: Equatable, Sendable {
    public let temperatureAdjustment: Double
    public let relativeHumidityAdjustment: Double
    public let sampleCount: Int
    public let analysisPeriod: String
    public let isProvisional: Bool
    public let caveat: String?

    public init(
        temperatureAdjustment: Double,
        relativeHumidityAdjustment: Double,
        sampleCount: Int,
        analysisPeriod: String,
        isProvisional: Bool = false,
        caveat: String? = nil
    ) {
        self.temperatureAdjustment = temperatureAdjustment
        self.relativeHumidityAdjustment = relativeHumidityAdjustment
        self.sampleCount = sampleCount
        self.analysisPeriod = analysisPeriod
        self.isProvisional = isProvisional
        self.caveat = caveat
    }
}

public struct BiasCorrectedRoomMeasurement: Equatable, Sendable {
    public let measurement: ClimateMeasurement
    public let correction: RoomSensorBiasCorrection
    public let baselineSensorName: String
    public let adjustedSensorName: String

    public init(
        measurement: ClimateMeasurement,
        correction: RoomSensorBiasCorrection,
        baselineSensorName: String,
        adjustedSensorName: String
    ) {
        self.measurement = measurement
        self.correction = correction
        self.baselineSensorName = baselineSensorName
        self.adjustedSensorName = adjustedSensorName
    }
}

public struct RoomSensorGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let sensors: [RoomSensorObservation]
    public let biasCorrectedMeasurement: BiasCorrectedRoomMeasurement?

    public init(
        id: String,
        name: String,
        sensors: [RoomSensorObservation],
        biasCorrectedMeasurement: BiasCorrectedRoomMeasurement? = nil
    ) {
        self.id = id
        self.name = name
        self.sensors = sensors
        self.biasCorrectedMeasurement = biasCorrectedMeasurement
    }

    public var isSMSReferenceRoom: Bool {
        sensors.contains(where: \.isReferenceSensor)
    }
}
