import Foundation

/// Each result keeps its real identity, including failed reads. A replacement
/// is never recorded under the identity of the unavailable sensor.
public struct CollectedSensor: Codable, Equatable, Sendable {
    public let id: String
    public let measuredAt: Date
    public let measurement: ClimateMeasurement?
    public let failure: String?

    public var name: String {
        switch id {
        case "stube": "Stube"
        case "schlafzimmer": "Schlafzimmer"
        case "buero-alois": "Büro Alois"
        case "sauna": "Sauna"
        case "eve-degree": "Eve Degree"
        case "homepod-terrasse": "HomePod Terrasse"
        case "homepod-kueche": "HomePod Küche"
        case "homepod-bad-peter": "HomePod Bad Peter"
        case "homepod-schlafzimmer": "HomePod Schlafzimmer"
        case "homepod-buero-alois-rechts": "HomePod Büro Alois Rechts"
        case "homepod-sauna-links": "HomePod Sauna Links"
        case "homepod-buero-peter": "HomePod Büro Peter"
        case "homepod-bad-alois": "HomePod Bad Alois"
        case "dachzimmer-sensor": "Dachzimmer"
        default: id
        }
    }
}

public struct SensorAcquisitionStatus: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let accepted: Bool
    public let message: String
    public let sensors: [CollectedSensor]

    public var outdoorSensors: [CollectedSensor] {
        sensors.filter { Self.outdoorIDs.contains($0.id) }
    }

    public var unavailableOutdoorIDs: Set<String> {
        Set(outdoorSensors.filter { $0.measurement == nil }.map(\.id))
    }

    public var outdoorSummary: String {
        guard accepted else { return message }
        let available = outdoorSensors.filter { $0.measurement != nil }
        let missing = outdoorSensors.filter { $0.measurement == nil }
        if !missing.isEmpty {
            return "Ersatzbetrieb · " + available.map(\.name).joined(separator: ", ")
                + " aktiv · " + missing.map(\.name).joined(separator: ", ")
                + " nicht verfügbar"
        }
        return "Aussenmittel aus Eve Degree und HomePod Terrasse"
    }

    static let outdoorIDs: Set<String> = ["eve-degree", "homepod-terrasse"]

    public static func unavailableReason(
        snapshot: SensorSnapshot?, status: SensorAcquisitionStatus?, now: Date = Date()
    ) -> String? {
        guard let snapshot else { return "Noch keine vollständige Messung vorhanden." }
        if let status, !status.accepted, status.timestamp >= snapshot.timestamp {
            return status.message
        }
        let age = now.timeIntervalSince(snapshot.timestamp)
        if age < -30 || age > 12 * 60 {
            return "Sensormessung veraltet · keine aktuelle Lüftungsempfehlung."
        }
        return nil
    }
}

public struct SensorAcquisitionStore {
    public init() {}

    public func load(from url: URL) throws -> SensorAcquisitionStatus? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SensorAcquisitionStatus.self, from: Data(contentsOf: url))
    }

    func write(_ status: SensorAcquisitionStatus, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(status).write(to: url, options: .atomic)
    }
}

struct SensorCollection: Decodable {
    let version: Int
    let timestamp: Date
    let sensors: [CollectedSensor]

    static func decode(
        _ text: String, now: Date,
        expectedIDs: Set<String> = ["stube", "schlafzimmer", "buero-alois", "sauna", "eve-degree", "homepod-terrasse"]
    ) throws -> SensorCollection {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let collection = try decoder.decode(Self.self, from: Data(text.utf8))
        guard collection.version == 1,
              Set(collection.sensors.map(\.id)) == expectedIDs,
              collection.sensors.count == expectedIDs.count else {
            throw SensorInputValidationError.incompleteSensorSet(
                "Der Connector muss für alle \(expectedIDs.count) erwarteten Sensoren genau ein Ergebnis melden."
            )
        }
        let age = now.timeIntervalSince(collection.timestamp)
        let times = collection.sensors.map(\.measuredAt)
        guard age >= -30, age <= 180,
              let first = times.min(), let last = times.max(),
              last.timeIntervalSince(first) <= 180 else {
            throw SensorInputValidationError.incompleteSensorSet("Sensorlauf ist nicht aktuell.")
        }
        for sensor in collection.sensors {
            let age = now.timeIntervalSince(sensor.measuredAt)
            guard age >= -30, age <= 180,
                  abs(collection.timestamp.timeIntervalSince(sensor.measuredAt)) <= 180 else {
                throw SensorInputValidationError.incompleteSensorSet(
                    "Abrufzeit von \(sensor.name) ist nicht aktuell."
                )
            }
            if let measurement = sensor.measurement {
                guard sensor.failure == nil,
                      measurement.temperature.isFinite,
                      measurement.humidity.isFinite,
                      (-40...60).contains(measurement.temperature),
                      (0...100).contains(measurement.humidity) else {
                    throw SensorInputValidationError.incompleteSensorSet(
                        "Ungültiges Temperatur-/Feuchtepaar von \(sensor.name)."
                    )
                }
            } else if !["unavailable", "timeout", "invalid"].contains(sensor.failure ?? "") {
                throw SensorInputValidationError.incompleteSensorSet(
                    "Fehlender Ausfallstatus für \(sensor.name)."
                )
            }
        }
        return collection
    }

    var indoorRooms: [SensorReading] { readings(outdoor: false) }
    var outdoorSensors: [SensorReading] { readings(outdoor: true) }

    private func readings(outdoor: Bool) -> [SensorReading] {
        let preferredOutdoor = sensors.first { $0.id == "eve-degree" && $0.measurement != nil }?.id
            ?? "homepod-terrasse"
        return sensors.compactMap { sensor in
            guard SensorAcquisitionStatus.outdoorIDs.contains(sensor.id) == outdoor,
                  let measurement = sensor.measurement else { return nil }
            return SensorReading(
                id: sensor.id, name: sensor.name, measurement: measurement,
                isPrimary: sensor.id == (outdoor ? preferredOutdoor : "stube")
            )
        }
    }

    func status(at date: Date, accepted: Bool, message: String) -> SensorAcquisitionStatus {
        SensorAcquisitionStatus(timestamp: date, accepted: accepted, message: message, sensors: sensors)
    }
}
