import Foundation

public struct HistoryPolicy {

    public init() {}

    public func shouldStore(
        previous: HistoryEntry?,
        current: HistoryEntry
    ) -> Bool {

        guard let previous else { return true }

        // Every accepted sensor snapshot is a measurement and must be visible
        // in the dashboard counter. Reprocessing the exact same snapshot (for
        // example a manual CLI call without fresh input) remains idempotent.
        return previous.timestamp != current.timestamp
    }
}
