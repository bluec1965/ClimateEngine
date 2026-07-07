import Foundation

public struct HistoryAnalyzer {

    public init() {}

    public func statistics(
        from entries: [HistoryEntry]
    ) -> HistoryStatistics {

        guard !entries.isEmpty else {
            return HistoryStatistics(
                measurementCount: 0,
                recommendationChanges: 0,
                ventilationPeriods: 0
            )
        }

        var recommendationChanges = 0
        var ventilationPeriods = 0

        var previousRecommendation: String?

        for entry in entries {

            if let previousRecommendation {

                if previousRecommendation != entry.recommendation {

                    recommendationChanges += 1

                    if entry.recommendation == "ventilate" {
                        ventilationPeriods += 1
                    }
                }

            } else {

                if entry.recommendation == "ventilate" {
                    ventilationPeriods += 1
                }
            }

            previousRecommendation = entry.recommendation
        }

        return HistoryStatistics(
            measurementCount: entries.count,
            recommendationChanges: recommendationChanges,
            ventilationPeriods: ventilationPeriods
        )
    }
}
