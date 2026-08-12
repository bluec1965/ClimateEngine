import Foundation

public enum SensorInputValidationError: Error, CustomStringConvertible {
    case awaitingConfirmation(String)
    case incompleteSensorSet(String)

    public var description: String {
        switch self {
        case .awaitingConfirmation(let reason):
            return "Sensormessung verworfen; Bestätigung abwarten: \(reason)"
        case .incompleteSensorSet(let reason):
            return "Sensormessung verworfen: \(reason)"
        }
    }
}

enum SensorInputRejectionKind {
    case awaitingConfirmation
    case incompleteSensorSet
}

struct SensorInputQualityDecision {
    let isAccepted: Bool
    let reason: String
    let rejectionKind: SensorInputRejectionKind?

    init(
        isAccepted: Bool,
        reason: String,
        rejectionKind: SensorInputRejectionKind? = nil
    ) {
        self.isAccepted = isAccepted
        self.reason = reason
        self.rejectionKind = rejectionKind ?? (isAccepted ? nil : .awaitingConfirmation)
    }
}

struct SensorInputQualityController {
    private let stateStore: SensorInputValidationStateStore
    private let comparisonWindow: TimeInterval
    private let temperatureJumpThreshold: Double
    private let humidityJumpThreshold: Double
    private let temperatureConfirmationTolerance: Double
    private let humidityConfirmationTolerance: Double
    private let requiredConfirmations: Int

    init(
        stateURL: URL,
        comparisonWindow: TimeInterval = 12 * 60,
        temperatureJumpThreshold: Double = 1.0,
        humidityJumpThreshold: Double = 8.0,
        temperatureConfirmationTolerance: Double = 0.4,
        humidityConfirmationTolerance: Double = 3.0,
        requiredConfirmations: Int = 3
    ) {
        stateStore = SensorInputValidationStateStore(fileURL: stateURL)
        self.comparisonWindow = comparisonWindow
        self.temperatureJumpThreshold = temperatureJumpThreshold
        self.humidityJumpThreshold = humidityJumpThreshold
        self.temperatureConfirmationTolerance = temperatureConfirmationTolerance
        self.humidityConfirmationTolerance = humidityConfirmationTolerance
        self.requiredConfirmations = requiredConfirmations
    }

    func evaluate(
        indoorRooms: [SensorReading],
        outdoorSensors: [SensorReading],
        previousSnapshot: SensorSnapshot?,
        now: Date
    ) throws -> SensorInputQualityDecision {
        if let previousSnapshot {
            let currentIndoorIDs = Set(indoorRooms.map(\.id))
            let currentOutdoorIDs = Set(outdoorSensors.map(\.id))
            let missingIndoor = previousSnapshot.indoorRooms.filter {
                !currentIndoorIDs.contains($0.id)
            }
            let missingOutdoor = previousSnapshot.outdoorSensors.filter {
                !currentOutdoorIDs.contains($0.id)
            }

            if !missingIndoor.isEmpty || !missingOutdoor.isEmpty {
                try stateStore.save(.empty)
                let missingNames = (missingIndoor + missingOutdoor)
                    .map(\.name)
                    .joined(separator: ", ")
                return SensorInputQualityDecision(
                    isAccepted: false,
                    reason: "Unvollständiger Sensorlauf; es fehlen: \(missingNames). "
                        + "Der letzte vollständige Snapshot bleibt erhalten.",
                    rejectionKind: .incompleteSensorSet
                )
            }
        }

        guard let current = indoorRooms.first(where: \.isPrimary) ?? indoorRooms.first,
              let previousSnapshot,
              let previous = previousSnapshot.indoorRooms.first(where: {
                  $0.id == current.id
              }) else {
            try stateStore.save(.empty)
            return SensorInputQualityDecision(
                isAccepted: true,
                reason: "Erste oder nicht vergleichbare Messung"
            )
        }

        var state = try stateStore.load()
        let elapsed = now.timeIntervalSince(previousSnapshot.timestamp)
        let hasRecentPendingMeasurement = state.pending.map {
            now.timeIntervalSince($0.lastSeenAt) >= 0
                && now.timeIntervalSince($0.lastSeenAt) <= comparisonWindow
        } ?? false
        guard elapsed >= 0,
              elapsed <= comparisonWindow || hasRecentPendingMeasurement else {
            try stateStore.save(.empty)
            return SensorInputQualityDecision(
                isAccepted: true,
                reason: "Vorherige Messung liegt ausserhalb des Prüfzeitfensters"
            )
        }

        let temperatureJump = abs(
            current.measurement.temperature - previous.measurement.temperature
        )
        let humidityJump = abs(
            current.measurement.humidity - previous.measurement.humidity
        )
        guard temperatureJump > temperatureJumpThreshold
                || humidityJump > humidityJumpThreshold else {
            try stateStore.save(.empty)
            return SensorInputQualityDecision(
                isAccepted: true,
                reason: "Messwertänderung ist plausibel"
            )
        }

        let matchesPendingMeasurement: Bool
        let confirmationCount: Int
        if let pending = state.pending,
           pending.sensorID == current.id,
           now.timeIntervalSince(pending.lastSeenAt) >= 0,
           now.timeIntervalSince(pending.lastSeenAt) <= comparisonWindow,
           abs(pending.temperature - current.measurement.temperature)
                <= temperatureConfirmationTolerance,
           abs(pending.humidity - current.measurement.humidity)
                <= humidityConfirmationTolerance {
            matchesPendingMeasurement = true
            confirmationCount = pending.confirmationCount + 1
        } else {
            matchesPendingMeasurement = false
            confirmationCount = 1
        }

        let reason = String(
            format: "%@ sprang in %.0f Minuten um %.2f °C und %.1f Prozentpunkte (Bestätigung %d/%d)",
            current.name,
            elapsed / 60,
            temperatureJump,
            humidityJump,
            confirmationCount,
            requiredConfirmations
        )

        guard confirmationCount >= requiredConfirmations else {
            state.pending = PendingSensorInput(
                sensorID: current.id,
                temperature: current.measurement.temperature,
                humidity: current.measurement.humidity,
                firstSeenAt: matchesPendingMeasurement
                    ? state.pending?.firstSeenAt ?? now
                    : now,
                lastSeenAt: now,
                confirmationCount: confirmationCount
            )
            try stateStore.save(state)
            return SensorInputQualityDecision(isAccepted: false, reason: reason)
        }

        try stateStore.save(.empty)
        return SensorInputQualityDecision(
            isAccepted: true,
            reason: "Auffällige Änderung wurde durch drei konsistente Messungen bestätigt"
        )
    }
}

private struct SensorInputValidationState: Codable {
    var pending: PendingSensorInput?

    static let empty = SensorInputValidationState(pending: nil)
}

private struct PendingSensorInput: Codable {
    let sensorID: String
    let temperature: Double
    let humidity: Double
    let firstSeenAt: Date
    let lastSeenAt: Date
    let confirmationCount: Int
}

private struct SensorInputValidationStateStore {
    let fileURL: URL

    func load() throws -> SensorInputValidationState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            SensorInputValidationState.self,
            from: Data(contentsOf: fileURL)
        )
    }

    func save(_ state: SensorInputValidationState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}

struct SensorInputAuditEntry: Codable {
    let timestamp: Date
    let accepted: Bool
    let reason: String
    let indoorRooms: [SensorReading]
    let outdoorSensors: [SensorReading]
}

struct SensorInputAuditWriter {
    let directory: URL

    func append(_ entry: SensorInputAuditEntry) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let fileURL = directory.appendingPathComponent(
            formatter.string(from: entry.timestamp) + ".jsonl"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.write(Data("\n".utf8))
        } else {
            var output = data
            output.append(Data("\n".utf8))
            try output.write(to: fileURL, options: .atomic)
        }
    }
}
