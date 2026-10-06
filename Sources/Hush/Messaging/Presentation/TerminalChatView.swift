import Foundation

final class TerminalChatView {
    enum InputAction: Equatable { case submit(String), quit, help, clear, unknownCommand(String) }
    private var input: [UInt8] = []
    private var escapeSequence = false
    private var escapeBytes: [UInt8] = []
    private var focusReportingObserved = false
    private(set) var focused = false
    private var peerTyping = false
    private var typingLineDrawn = false
    static let typingNotice = "상대 입력 중…"

    func finishReadCheck() {
        if !focusReportingObserved { focused = false }
    }
    private(set) var displayedIncoming: Set<MessageIdentity> = []
    private let write: (String) -> Void
    private let calendar: Calendar
    private let formatter: DateFormatter
    private let now: () -> Date

    init(write: @escaping (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) },
         timeZone: TimeZone = .current, now: @escaping () -> Date = Date.init) {
        self.write = write
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
    }

    static func clean(_ text: String) -> String {
        String(text.unicodeScalars.filter { $0.value >= 32 && !(127...159).contains($0.value) })
    }

    // Hush 출력은 고른 글자 색으로, 내 메시지는 같은 계열의 밝은 색에 굵게 구분합니다.
    static func styled(_ text: String, own: Bool = false) -> String {
        own ? TerminalPalette.current.own(text) : TerminalPalette.current.normal(text)
    }

    var draft: String { String(decoding: input, as: UTF8.self) }

    // /로 시작하는 명령 입력은 메시지 작성으로 보지 않으며, //로 시작하면 메시지입니다.
    var composingMessage: Bool {
        let text = draft
        return !text.isEmpty && (!text.hasPrefix("/") || text.hasPrefix("//"))
    }

    func showMessage(_ record: RecordedMessage, isNew: Bool) {
        if !record.isOutgoing { displayedIncoming.insert(record.message.identity) }
        let message = record.message
        let notice = !record.isOutgoing && isNew ? "새 메시지 " : ""
        let text = "\(timestamp(message.identity.createdAt)) \(notice)[\(Self.clean(message.identity.senderIP))] \(Self.clean(message.content))"
        write("\(clearPromptArea())\(Self.styled(text, own: record.isOutgoing))\n")
        redraw()
    }

    // 메시지를 만든 시각으로, 오늘이면 시:분만, 지난 날은 날짜를, 올해가 아니면 연도까지 붙입니다.
    private func timestamp(_ date: Date) -> String {
        let today = now()
        formatter.dateFormat = calendar.isDate(date, inSameDayAs: today) ? "HH:mm"
            : calendar.isDate(date, equalTo: today, toGranularity: .year) ? "MM-dd HH:mm" : "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    func showPeerTyping(_ typing: Bool) {
        guard typing != peerTyping else { return }
        peerTyping = typing
        redraw()
    }

    func showStatus(ip: String?, online: Bool) {
        notice("상대 \(ip.map(Self.clean) ?? "미확인"): \(online ? "온라인" : "오프라인")")
    }

    func notice(_ text: String) {
        write("\(clearPromptArea())\(Self.styled(Self.clean(text)))\n")
        redraw()
    }

    // 상대가 입력 중이면 입력 줄 바로 위에 한 줄로 표시하며, 스크롤 기록에는 남기지 않습니다.
    func redraw() {
        let typingLine = peerTyping ? "\(Self.styled(Self.typingNotice))\n" : ""
        write("\(clearPromptArea())\(typingLine)\r\u{1B}[2K\(Self.styled("> \(draft)"))")
        typingLineDrawn = peerTyping
    }

    // 입력 줄과 그 위의 입력 중 줄을 지우고, 커서를 지운 영역의 첫 줄 처음에 둡니다.
    private func clearPromptArea() -> String {
        defer { typingLineDrawn = false }
        return typingLineDrawn ? "\r\u{1B}[2K\u{1B}[1A\u{1B}[2K" : "\r\u{1B}[2K"
    }

    func consume(_ bytes: [UInt8]) -> [InputAction] {
        var actions: [InputAction] = []
        for byte in bytes {
            if escapeSequence {
                escapeBytes.append(byte)
                if byte >= 64 && byte <= 126 && byte != 91 {
                    if escapeBytes == [91, 73] { focusReportingObserved = true; focused = true }
                    if escapeBytes == [91, 79] { focusReportingObserved = true; focused = false }
                    escapeSequence = false
                    escapeBytes.removeAll()
                }
                continue
            }
            if byte != 27 { focused = true }
            switch byte {
            case 27: escapeSequence = true
            case 0...3, 5...7, 14...26, 28...31: break
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
        "Ctrl-C  즉시 종료",
    ]

    func showHelp() {
        write(clearPromptArea())
        for line in Self.helpLines { write("\r\u{1B}[2K\(Self.styled(line))\n") }
        redraw()
    }

    // 터미널의 clear 명령처럼 화면과 스크롤 기록을 지우며, 저장된 대화 기록은 건드리지 않습니다.
    func clearScreen() {
        write("\u{1B}[H\u{1B}[2J\u{1B}[3J")
        typingLineDrawn = false
        redraw()
    }

    func finish() { write("\(clearPromptArea())\n") }

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
