import Foundation

public struct HistorySummary {

    public let measurementCount: Int
    public let firstMeasurement: Date?
    public let lastMeasurement: Date?

    public init(
        measurementCount: Int,
        firstMeasurement: Date?,
        lastMeasurement: Date?
    ) {
        self.measurementCount = measurementCount
        self.firstMeasurement = firstMeasurement
        self.lastMeasurement = lastMeasurement
    }
}
