import Foundation
import Testing
@testable import Hush

struct TerminalChatViewTests {
    @Test func focusReportsSurviveSplitInputWithoutEnteringMessage() {
        let view = TerminalChatView { _ in }
        _ = view.consume([27, 91])
        _ = view.consume([73])
        #expect(view.focused)
        view.finishReadCheck()
        #expect(view.focused)
        _ = view.consume(Array("hello".utf8))
        _ = view.consume([27, 91, 79])
        #expect(!view.focused)
        #expect(view.consume([13]) == [.submit("hello")])
    }

    @Test func unsupportedTerminalOnlyAcknowledgesOnInput() {
        let view = TerminalChatView { _ in }
        #expect(!view.focused)
        _ = view.consume(Array("a".utf8))
        #expect(view.focused)
        view.finishReadCheck()
        #expect(!view.focused)
    }

    private func record(outgoing: Bool, content: String = "안녕하세요") -> RecordedMessage {
        RecordedMessage(message: ChatMessage(identity: MessageIdentity(senderIP: "192.168.0.34", createdAt: Date(), contentHash: "hash"),
            content: content), isOutgoing: outgoing)
    }

    @Test func 내_메시지는_하이라이트되고_새_상대_메시지는_조용하게_표시된다() {
        // Given: 터미널 출력과 내 메시지 및 상대 메시지가 있습니다.
        var output = ""
        let view = TerminalChatView { output += $0 }
        // When: 내 메시지와 새 상대 메시지를 표시합니다.
        view.showMessage(record(outgoing: true), isNew: true)
        view.showMessage(record(outgoing: false), isNew: true)
        // Then: 내 메시지는 밝은 초록·굵기로 구분되고 새 메시지는 초록으로 소리 없이 표시됩니다.
        #expect(output.contains("\u{1B}[1;92m[192.168.0.34] 안녕하세요\u{1B}[0m"))
        #expect(output.contains("\u{1B}[32m새 메시지 [192.168.0.34] 안녕하세요\u{1B}[0m"))
        #expect(!output.contains("\u{7}"))
    }

    @Test func 한글_입력과_지우기와_종료_명령을_처리한다() {
        // Given: 채팅 입력 화면이 있습니다.
        let view = TerminalChatView { _ in }
        // When: 한글을 입력하고 마지막 글자를 지운 뒤 전송·종료합니다.
        _ = view.consume(Array("안녕요".utf8))
        _ = view.consume([127])
        let submitted = view.consume([13])
        let quit = view.consume(Array("/quit\r".utf8))
        // Then: 완전한 한글 메시지와 종료 동작을 구분합니다.
        #expect(submitted == [.submit("안녕")])
        #expect(quit == [.quit])
    }

    @Test func 슬래시로_시작하는_입력은_전송하지_않고_명령으로_해석한다() {
        // Given: 채팅 입력 화면이 있습니다.
        let view = TerminalChatView { _ in }
        // When: 명령과 오타, 앞뒤 공백이 있는 명령을 입력합니다.
        let help = view.consume(Array("/help\r".utf8))
        let clear = view.consume(Array("/clear \r".utf8))
        let typo = view.consume(Array("/hlep 안녕\r".utf8))
        let slash = view.consume(Array("/\r".utf8))
        // Then: 알려진 명령은 해당 동작으로, 모르는 명령은 전송하지 않고 안내 대상으로 구분합니다.
        #expect(help == [.help])
        #expect(clear == [.clear])
        #expect(typo == [.unknownCommand("/hlep")])
        #expect(slash == [.unknownCommand("/")])
    }

    @Test func 두_개의_슬래시로_슬래시로_시작하는_메시지를_보낸다() {
        // Given: 채팅 입력 화면이 있습니다.
        let view = TerminalChatView { _ in }
        // When: 슬래시 두 개로 시작하는 글을 입력합니다.
        let submitted = view.consume(Array("//help는 명령이에요\r".utf8))
        // Then: 앞의 슬래시 하나를 뗀 메시지로 보냅니다.
        #expect(submitted == [.submit("/help는 명령이에요")])
    }

    @Test func 도움말은_명령과_단축키를_초록으로_보여준다() {
        // Given: 작성 중인 입력이 있는 채팅 화면이 있습니다.
        var output = ""
        let view = TerminalChatView { output += $0 }
        _ = view.consume(Array("작성 중".utf8))
        // When: 도움말을 표시합니다.
        view.showHelp()
        // Then: 모든 명령을 초록으로 보여주고 작성하던 입력을 다시 표시합니다.
        for line in TerminalChatView.helpLines { #expect(output.contains("\u{1B}[32m\(line)\u{1B}[0m")) }
        #expect(output.hasSuffix("> 작성 중\u{1B}[0m"))
    }

    @Test func 화면_지우기는_스크롤_기록까지_지우고_입력을_다시_표시한다() {
        // Given: 작성 중인 입력이 있는 채팅 화면이 있습니다.
        var output = ""
        let view = TerminalChatView { output += $0 }
        _ = view.consume(Array("작성 중".utf8))
        output = ""
        // When: 화면을 지웁니다.
        view.clearScreen()
        // Then: 화면과 스크롤 기록을 지운 뒤 작성하던 입력을 다시 표시합니다.
        #expect(output.hasPrefix("\u{1B}[H\u{1B}[2J\u{1B}[3J"))
        #expect(output.hasSuffix("> 작성 중\u{1B}[0m"))
    }

    @Test func 새_출력이_와도_작성하던_입력이_유지된다() {
        // Given: 메시지를 작성하고 있습니다.
        var output = ""
        let view = TerminalChatView { output += $0 }
        _ = view.consume(Array("작성 중".utf8))
        // When: 상대 메시지가 표시됩니다.
        view.showMessage(record(outgoing: false), isNew: true)
        // Then: 입력 프롬프트에 작성하던 내용이 다시 표시됩니다.
        #expect(output.hasSuffix("> 작성 중\u{1B}[0m"))
        #expect(view.consume([13]) == [.submit("작성 중")])
    }

    @Test func 메시지의_제어_문자는_터미널_명령으로_실행되지_않는다() {
        // Given: 화면 지우기와 bell 제어 문자가 포함된 메시지가 있습니다.
        let content = "내용\u{1B}[2J\u{7}\n추가"
        // When: 표시할 내용을 정리합니다.
        let cleaned = TerminalChatView.clean(content)
        // Then: 원격 내용으로 터미널 제어 시퀀스가 실행되지 않습니다.
        #expect(!cleaned.contains("\u{1B}"))
        #expect(!cleaned.contains("\u{7}"))
        #expect(cleaned.contains("내용"))
    }
}
