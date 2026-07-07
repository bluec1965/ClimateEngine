import Foundation

public enum WindowState: String, Codable, Equatable {

    /// Das System wartet auf den richtigen Zeitpunkt,
    /// um das Öffnen der Fenster zu empfehlen.
    case waitingForOpening

    /// Das Öffnen wurde empfohlen.
    /// Das System wartet nun auf den richtigen Zeitpunkt,
    /// um das Schliessen der Fenster zu empfehlen.
    case waitingForClosing
}
