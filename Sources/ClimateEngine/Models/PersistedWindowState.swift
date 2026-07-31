import Foundation

public struct PersistedWindowState: Codable, Equatable {
    public let state: WindowState
    public let day: String

    public init(state: WindowState, day: String) {
        self.state = state
        self.day = day
    }
}
