import Foundation

public struct CLIArguments {

    public let indoorTemperature: String
    public let indoorHumidity: String
    public let outdoorTemperature: String
    public let outdoorHumidity: String

    public static func parse(
        _ arguments: [String] = Array(CommandLine.arguments.dropFirst())
    ) throws -> CLIArguments {

        var values: [String: String] = [:]

        var iterator = arguments.makeIterator()

        while let key = iterator.next() {
            guard let value = iterator.next() else {
                throw CLIError.missingValue(key)
            }

            values[key] = value
        }

        func required(_ key: String) throws -> String {
            guard let value = values[key] else {
                throw CLIError.missingArgument(key)
            }
            return value
        }

        return CLIArguments(
            indoorTemperature: try required("--indoor-temperature"),
            indoorHumidity: try required("--indoor-humidity"),
            outdoorTemperature: try required("--outdoor-temperature"),
            outdoorHumidity: try required("--outdoor-humidity")
        )
    }
}

public enum CLIError: Error, LocalizedError {

    case missingArgument(String)
    case missingValue(String)

    public var errorDescription: String? {

        switch self {

        case .missingArgument(let name):
            return "Fehlender Parameter \(name)"

        case .missingValue(let name):
            return "Kein Wert für \(name)"
        }
    }
}
