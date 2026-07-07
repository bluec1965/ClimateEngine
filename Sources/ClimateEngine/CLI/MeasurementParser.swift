import Foundation

public enum MeasurementParser {

    public static func double(from text: String) throws -> Double {
        let cleaned = text
            .replacingOccurrences(of: ",", with: ".")
            .filter { character in
                character.isNumber || character == "." || character == "-"
            }

        guard let value = Double(cleaned) else {
            throw CLIError.invalidNumber(text)
        }

        return value
    }
}
