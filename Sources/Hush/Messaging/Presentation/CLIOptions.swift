import Foundation

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct CLIOptions {
    // 사용자에게 안내하는 명령은 메뉴와 update·upgrade뿐이며, 나머지는 업데이트 검증과 테스트용입니다.
    enum Command { case menu, upgrade, chat, receive, help, version }
    let command: Command
    let interfaceName: String?
    let port: UInt16
    let historyDirectory: URL

    static let defaultHistoryDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Hush", isDirectory: true)

    init(arguments: [String]) throws {
        var command = Command.menu
        var interface: String?
        var port = HushConfig.udpPort
        var directory = Self.defaultHistoryDirectory
        var index = 0
        if let first = arguments.first, !first.hasPrefix("-") {
            switch first {
            case "update", "upgrade": command = .upgrade
            case "chat": command = .chat
            case "receive": command = .receive
            default: throw CLIError("알 수 없는 명령: \(first)\n\(Self.help)")
            }
            index += 1
        }
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--help" || argument == "-h" {
                command = .help
            } else if argument == "--version" {
                command = .version
            } else {
                guard ["--interface", "--port", "--history-directory"].contains(argument) else {
                    throw CLIError("알 수 없는 옵션: \(argument)\n\(Self.help)")
                }
                index += 1
                guard index < arguments.count, !arguments[index].isEmpty, !arguments[index].hasPrefix("--") else {
                    throw CLIError("\(argument)에 값이 필요합니다")
                }
                switch argument {
                case "--interface": interface = arguments[index]
                case "--port":
                    guard let value = UInt16(arguments[index]), value != 0 else { throw CLIError("포트는 1~65535 범위입니다") }
                    port = value
                default: directory = URL(fileURLWithPath: arguments[index], isDirectory: true).standardizedFileURL
                }
            }
            index += 1
        }
        self.command = command
        interfaceName = interface
        self.port = port
        historyDirectory = directory
    }

    func networkInterface(from interfaces: [NetworkInterface], preference: NetworkPreference) throws -> NetworkInterface {
        if let interfaceName {
            guard let selected = interfaces.first(where: { $0.name == interfaceName }) else {
                throw CLIError("사용 가능한 IPv4 브로드캐스트 인터페이스가 아닙니다: \(interfaceName)")
            }
            return selected
        }
        let sorted = interfaces.sorted { $0.name < $1.name }
        guard let first = sorted.first else {
            throw CLIError("사용 가능한 IPv4 브로드캐스트 네트워크가 없습니다")
        }
        if sorted.count == 1 { return first }
        if let wifi = sorted.first(where: { preference.wifiNames.contains($0.name) }) { return wifi }
        if let primary = sorted.first(where: { $0.name == preference.primaryName }) { return primary }
        throw CLIError("네트워크를 자동으로 정할 수 없습니다 (연결된 네트워크: \(sorted.map(\.name).joined(separator: ", ")))")
    }

    static let help = """
    사용법:
      hush          채팅과 기록 보기 메뉴
      hush update   새 버전 확인 후 설치
      hush upgrade  hush update와 같음
    """
}
