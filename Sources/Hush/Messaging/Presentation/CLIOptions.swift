import Foundation

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct CLIOptions {
    enum Command { case menu, chat, receive, help, version }
    let command: Command
    let interfaceName: String?
    let port: UInt16
    let historyDirectory: URL

    init(arguments: [String]) throws {
        var command = Command.menu
        var interface: String?
        var port = HushConfig.udpPort
        var directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Hush", isDirectory: true)
        var index = 0
        if let first = arguments.first, !first.hasPrefix("-") {
            switch first {
            case "chat": command = .chat
            case "receive": command = .receive
            default: throw CLIError("알 수 없는 명령: \(first)")
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
                    throw CLIError("알 수 없는 옵션: \(argument)")
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
        throw CLIError("네트워크를 자동으로 정할 수 없습니다. --interface로 선택하세요: \(sorted.map(\.name).joined(separator: ", "))")
    }

    static let help = """
    사용법: hush [chat|receive] [옵션]
      (명령 없음)  비밀번호 입력 후 메뉴에서 채팅·기록 보기·수신기 선택
      chat       비밀번호 입력 후 대화 조회와 채팅
      receive    비밀번호 입력 후 화면 없이 메시지 수신·저장
      --interface 이름       사용할 네트워크 (기본: Wi-Fi, 없으면 기본 경로 네트워크)
      --port 번호            UDP 포트 (기본: \(HushConfig.udpPort))
      --history-directory 경로  개인 기록 위치
      --help                 도움말
      --version              프로그램 버전
    채팅 종료: /quit 또는 Ctrl-D
    """
}
