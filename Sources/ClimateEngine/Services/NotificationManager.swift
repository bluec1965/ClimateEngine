import Foundation

public enum NotificationAction: Equatable {
    case none
    case openWindows
    case closeWindows
}

public struct NotificationResult: Equatable {
    public let action: NotificationAction
    public let newState: WindowState

    public init(
        action: NotificationAction,
        newState: WindowState
    ) {
        self.action = action
        self.newState = newState
    }
}

public struct NotificationManager {

    public init() {}

    public func evaluate(
        recommendation: VentilationRecommendation,
        state: WindowState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> NotificationResult {

        let hour = calendar.component(.hour, from: now)

        switch state {

        case .waitingForOpening:

            if (18...23).contains(hour),
               recommendation == .ventilate {

                return NotificationResult(
                    action: .openWindows,
                    newState: .waitingForClosing
                )
            }

        case .waitingForClosing:

            if (5...9).contains(hour),
               recommendation == .closeWindows {

                return NotificationResult(
                    action: .closeWindows,
                    newState: .waitingForOpening
                )
            }
        }

        return NotificationResult(
            action: .none,
            newState: state
        )
    }
}
