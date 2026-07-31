import Foundation
import ClimateEngine

do {
    let input = String(
        data: FileHandle.standardInput.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let result = try ClimateEngineCommand().run(
        arguments: Array(CommandLine.arguments.dropFirst()),
        standardInput: input
    )
    print(result)
} catch {
    let message = "ClimateEngineCLI error: \(String(reflecting: error))\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
