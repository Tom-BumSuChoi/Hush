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
            case .menu: try CLIApplication.runMenu(options)
            case .upgrade: try UpgradeCommand.run()
            case .chat, .receive: try CLIApplication.run(options)
            }
        } catch {
            try? FileHandle.standardError.write(contentsOf: Data("Hush: \(error)\n".utf8))
            exit(1)
        }
    }
}
