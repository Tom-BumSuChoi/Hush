import Foundation

final class MainMenu {
    enum Choice: Equatable { case chat, history, receive, quit }
    private let write: (String) -> Void

    init(write: @escaping (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) }) {
        self.write = write
    }

    static func choice(for byte: UInt8) -> Choice? {
        switch byte {
        case UInt8(ascii: "1"): .chat
        case UInt8(ascii: "2"): .history
        case UInt8(ascii: "3"): .receive
        case UInt8(ascii: "q"), UInt8(ascii: "Q"), 4: .quit
        default: nil
        }
    }

    func show(network: NetworkInterface?, isWiFi: Bool) {
        let place = network.map { "\($0.name)\(isWiFi ? " (Wi-Fi)" : "") \($0.ip)" } ?? "네트워크 없음"
        write("\n" + TerminalChatView.styled("Hush \(HushConfig.version) · \(TerminalChatView.clean(place))") + "\n")
        write(TerminalChatView.styled("1 채팅   2 기록 보기   3 수신기 실행   q 종료") + "\n")
        write(TerminalChatView.styled("선택: "))
    }

    func notice(_ text: String) {
        write("\r\u{1B}[2K\(TerminalChatView.styled(TerminalChatView.clean(text)))\n")
    }
}
