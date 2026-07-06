import Foundation

public final class SensorSnapshotWriter {

    public init() {}

    public func write(
        indoorTemperature: Double,
        indoorHumidity: Double,
        outdoorTemperature: Double,
        outdoorHumidity: Double,
        to url: URL
    ) throws {

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())

        let json = """
        {
          "version": 1,
          "timestamp": "\(timestamp)",
          "source": "ClimateEngineCLI",

          "indoor": {
            "temperature": "\(String(format: "%.3f", indoorTemperature)) °C",
            "humidity": \(indoorHumidity)
          },

          "outdoor": {
            "temperature": "\(String(format: "%.3f", outdoorTemperature)) °C",
            "humidity": \(outdoorHumidity)
          }
        }
        """

        try json.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
    }
}
