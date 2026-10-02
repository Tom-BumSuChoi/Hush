import Foundation
import Testing
@testable import Hush

struct TerminalHistoryViewTests {
    private func record(outgoing: Bool, content: String, senderIP: String = "192.168.0.34") -> RecordedMessage {
        // 2026-10-02 00:30:00 UTC
        RecordedMessage(message: ChatMessage(identity: MessageIdentity(senderIP: senderIP,
            createdAt: Date(timeIntervalSince1970: 1_790_901_000), contentHash: "hash"), content: content), isOutgoing: outgoing)
    }

    @Test func 기록을_생성_시각과_함께_초록으로_표시한다() {
        // Given: 상대 메시지와 내 메시지가 저장되어 있습니다.
        var output = ""
        let view = TerminalHistoryView(write: { output += $0 }, timeZone: TimeZone(identifier: "Asia/Seoul")!)
        // When: 기록을 표시합니다.
        view.show([record(outgoing: false, content: "점심 뭐 먹어요?"),
                   record(outgoing: true, content: "김치찌개요", senderIP: "192.168.0.35")])
        // Then: 건수와 현지 시각이 표시되고 내 메시지는 밝은 초록 굵게 구분됩니다.
        #expect(output.contains("── 기록 2건 ──"))
        #expect(output.contains("\u{1B}[32m2026-10-02 09:30 [192.168.0.34] 점심 뭐 먹어요?\u{1B}[0m"))
        #expect(output.contains("\u{1B}[1;92m2026-10-02 09:30 [192.168.0.35] 김치찌개요\u{1B}[0m"))
        #expect(output.contains("아무 키나 누르면 메뉴로 돌아갑니다"))
    }

    @Test func 기록이_없으면_없다고_알린다() {
        // Given: 저장된 기록이 없습니다.
        var output = ""
        let view = TerminalHistoryView(write: { output += $0 })
        // When: 기록을 표시합니다.
        view.show([])
        // Then: 빈 목록 대신 기록이 없다고 표시합니다.
        #expect(output.contains("저장된 기록이 없습니다"))
    }

    @Test func 기록의_제어_문자는_터미널_명령으로_실행되지_않는다() {
        // Given: 화면 지우기 제어 문자가 포함된 메시지가 저장되어 있습니다.
        var output = ""
        let view = TerminalHistoryView(write: { output += $0 })
        // When: 기록을 표시합니다.
        view.show([record(outgoing: false, content: "내용\u{1B}[2J추가")])
        // Then: 원격 내용의 화면 지우기 명령이 출력되지 않습니다.
        #expect(!output.contains("\u{1B}[2J"))
        #expect(output.contains("내용[2J추가"))
    }
}
