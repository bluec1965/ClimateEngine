import Foundation

public struct HistoryStatistics: Equatable {

    public let measurementCount: Int
    public let recommendationChanges: Int
    public let ventilationPeriods: Int

    public init(
        measurementCount: Int,
        recommendationChanges: Int,
        ventilationPeriods: Int
    ) {
        self.measurementCount = measurementCount
        self.recommendationChanges = recommendationChanges
        self.ventilationPeriods = ventilationPeriods
    }
}
