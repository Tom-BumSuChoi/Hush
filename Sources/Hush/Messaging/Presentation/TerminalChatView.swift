import Foundation

final class TerminalChatView {
    enum InputAction: Equatable { case submit(String), quit }
    private var input: [UInt8] = []
    private var escapeSequence = false
    private let write: (String) -> Void

    init(write: @escaping (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) }) {
        self.write = write
    }

    static func clean(_ text: String) -> String {
        String(text.unicodeScalars.filter { $0.value >= 32 && !(127...159).contains($0.value) })
    }

    // Hush 출력은 초록으로, 내 메시지는 밝은 초록 굵게 구분합니다.
    static func styled(_ text: String, own: Bool = false) -> String {
        "\u{1B}[\(own ? "1;92" : "32")m\(text)\u{1B}[0m"
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
                if text == "/quit" { actions.append(.quit) }
                else if !text.isEmpty { actions.append(.submit(text)) }
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

    func finish() { write("\r\u{1B}[2K\n") }
}
