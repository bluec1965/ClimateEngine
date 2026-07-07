import Foundation

public enum MeasurementParser {

    public static func double(from value: String) throws -> Double {

        let cleaned = value
            .replacingOccurrences(of: "°C", with: "")
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let number = Double(cleaned) else {
            throw MeasurementParserError.invalidValue(value)
        }

        return number
    }
}

public enum MeasurementParserError: Error {
    case invalidValue(String)
}
