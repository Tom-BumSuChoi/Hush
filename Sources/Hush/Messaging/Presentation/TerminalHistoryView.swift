import Foundation

final class TerminalHistoryView {
    private let write: (String) -> Void
    private let formatter: DateFormatter

    init(write: @escaping (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) },
         timeZone: TimeZone = .current) {
        self.write = write
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
    }

    func show(_ records: [RecordedMessage]) {
        write("\r\u{1B}[2K\n" + TerminalChatView.styled(records.isEmpty ? "저장된 기록이 없습니다" : "── 기록 \(records.count)건 ──") + "\n")
        for record in records {
            let message = record.message
            let text = "\(formatter.string(from: message.identity.createdAt)) [\(TerminalChatView.clean(message.identity.senderIP))] \(TerminalChatView.clean(message.content))"
            write(TerminalChatView.styled(text, own: record.isOutgoing) + "\n")
        }
        write(TerminalChatView.styled("아무 키나 누르면 메뉴로 돌아갑니다"))
    }
}
