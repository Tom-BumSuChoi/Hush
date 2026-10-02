import Foundation

final class TerminalChatView {
    enum InputAction: Equatable { case submit(String), quit, help, clear, unknownCommand(String) }
    private var input: [UInt8] = []
    private var escapeSequence = false
    private let write: (String) -> Void

    init(write: @escaping (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) }) {
        self.write = write
    }

    static func clean(_ text: String) -> String {
        String(text.unicodeScalars.filter { $0.value >= 32 && !(127...159).contains($0.value) })
    }

    // Hush 출력은 고른 글자 색으로, 내 메시지는 같은 계열의 밝은 색에 굵게 구분합니다.
    static func styled(_ text: String, own: Bool = false) -> String {
        own ? TerminalPalette.current.own(text) : TerminalPalette.current.normal(text)
    }

    func showMessage(_ record: RecordedMessage, isNew: Bool) {
        let message = record.message
        let text = "[\(Self.clean(message.identity.senderIP))] \(Self.clean(message.content))"
        let line = record.isOutgoing ? Self.styled(text, own: true) : Self.styled("\(isNew ? "새 메시지 " : "")\(text)")
        write("\r\u{1B}[2K\(line)\n")
        redraw()
    }

    func showStatus(ip: String?, online: Bool) {
        notice("상대 \(ip.map(Self.clean) ?? "미확인"): \(online ? "온라인" : "오프라인")")
    }

    func notice(_ text: String) {
        write("\r\u{1B}[2K\(Self.styled(Self.clean(text)))\n")
        redraw()
    }

    func redraw() {
        write("\r\u{1B}[2K\(Self.styled("> \(String(decoding: input, as: UTF8.self))"))")
    }

    func consume(_ bytes: [UInt8]) -> [InputAction] {
        var actions: [InputAction] = []
        for byte in bytes {
            if escapeSequence {
                if byte >= 64 && byte <= 126 && byte != 91 { escapeSequence = false }
                continue
            }
            switch byte {
            case 27: escapeSequence = true
            case 4:
                if input.isEmpty { actions.append(.quit) }
            case 10, 13:
                let text = String(decoding: input, as: UTF8.self)
                input.removeAll()
                if let action = Self.action(for: text) { actions.append(action) }
            case 8, 127:
                var text = String(decoding: input, as: UTF8.self)
                if !text.isEmpty { text.removeLast() }
                input = Array(text.utf8)
            case 21: input.removeAll()
            default:
                if byte >= 32 { input.append(byte) }
            }
        }
        redraw()
        return actions
    }

    static let helpLines = [
        "/help   명령 보기",
        "/clear  화면 지우기 (대화 기록은 유지)",
        "/quit   메뉴로 돌아가기 (빈 입력에서 Ctrl-D도 같음)",
        "//내용  /로 시작하는 메시지 보내기",
        "Ctrl-U 입력 지우기 · Ctrl-C 즉시 종료",
    ]

    func showHelp() {
        for line in Self.helpLines { write("\r\u{1B}[2K\(Self.styled(line))\n") }
        redraw()
    }

    // 터미널의 clear 명령처럼 화면과 스크롤 기록을 지우며, 저장된 대화 기록은 건드리지 않습니다.
    func clearScreen() {
        write("\u{1B}[H\u{1B}[2J\u{1B}[3J")
        redraw()
    }

    func finish() { write("\r\u{1B}[2K\n") }

    // /로 시작하는 입력은 전송하지 않는 명령으로 해석하며, /로 시작하는 메시지는 //로 보냅니다.
    private static func action(for text: String) -> InputAction? {
        guard !text.isEmpty else { return nil }
        guard text.hasPrefix("/") else { return .submit(text) }
        if text.hasPrefix("//") { return .submit(String(text.dropFirst())) }
        let command = text.trimmingCharacters(in: .whitespaces)
        switch command {
        case "/quit": return .quit
        case "/help": return .help
        case "/clear": return .clear
        default: return .unknownCommand(String(command.split(separator: " ", maxSplits: 1).first ?? "/"))
        }
    }
}
