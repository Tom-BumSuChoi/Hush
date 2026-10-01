import Darwin
import Foundation

@main
struct Hush {
    static func main() {
        do {
            let options = try CLIOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            switch options.command {
            case .help: print(CLIOptions.help)
            case .version: print(HushConfig.version)
            case .chat, .receive: try CLIApplication.run(options)
            }
        } catch {
            FileHandle.standardError.write(Data("Hush: \(error)\n".utf8))
            exit(1)
        }
    }
}
