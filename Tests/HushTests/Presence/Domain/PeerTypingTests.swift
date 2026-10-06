import Foundation
import Testing
@testable import Hush

struct PeerTypingTests {
    @Test func 입력_중_신호를_받은_적이_없으면_입력_중이_아니다() {
        // Given: 신호를 받은 적이 없는 상대가 있습니다.
        let peer = PeerTyping()

        // When: 현재 시각에 입력 중인지 확인합니다.
        let isTyping = peer.isTyping(at: Date(timeIntervalSince1970: 1_000))

        // Then: 입력 중이 아닙니다.
        #expect(!isTyping)
    }

    @Test func 입력_중_신호를_받으면_5초_직전까지_입력_중이다() {
        // Given: 상대의 입력 중 신호를 받았습니다.
        var peer = PeerTyping()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receive(.typing, at: receivedAt)

        // When: 수신 시각과 4.999초 후에 확인합니다.
        // Then: 두 시각 모두 입력 중입니다.
        #expect(peer.isTyping(at: receivedAt))
        #expect(peer.isTyping(at: receivedAt.addingTimeInterval(4.999)))
    }

    @Test func 입력_중_신호를_받고_정확히_5초가_지나면_입력_중이_아니다() {
        // Given: 상대의 입력 중 신호를 받았습니다.
        var peer = PeerTyping()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receive(.typing, at: receivedAt)

        // When: 추가 신호 없이 정확히 5초 후에 확인합니다.
        let isTyping = peer.isTyping(at: receivedAt.addingTimeInterval(5))

        // Then: 상대가 키를 멈춘 것으로 보고 표시를 끝냅니다.
        #expect(!isTyping)
    }

    @Test func 입력_중_신호를_다시_받으면_마지막_수신_시각을_기준으로_유지한다() {
        // Given: 입력 중 신호를 받고 2초 후에 다시 받았습니다.
        var peer = PeerTyping()
        let firstReceivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receive(.typing, at: firstReceivedAt)
        peer.receive(.typing, at: firstReceivedAt.addingTimeInterval(2))

        // When: 첫 수신으로부터 5초 후와 마지막 수신으로부터 5초 후에 확인합니다.
        // Then: 마지막 수신으로부터 5초가 지나야 입력 중이 아닙니다.
        #expect(peer.isTyping(at: firstReceivedAt.addingTimeInterval(5)))
        #expect(!peer.isTyping(at: firstReceivedAt.addingTimeInterval(7)))
    }

    @Test func 정지_신호를_받으면_바로_입력_중이_아니다() {
        // Given: 상대의 입력 중 신호를 받았습니다.
        var peer = PeerTyping()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receive(.typing, at: receivedAt)

        // When: 1초 후에 정지 신호를 받습니다.
        peer.receive(.stopped, at: receivedAt.addingTimeInterval(1))

        // Then: 만료를 기다리지 않고 입력 중이 아닙니다.
        #expect(!peer.isTyping(at: receivedAt.addingTimeInterval(1)))
    }

    @Test func 표시를_끝내면_바로_입력_중이_아니다() {
        // Given: 상대의 입력 중 신호를 받았습니다.
        var peer = PeerTyping()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receive(.typing, at: receivedAt)

        // When: 상대 메시지가 와서 표시를 끝냅니다.
        peer.clear()

        // Then: 입력 중이 아닙니다.
        #expect(!peer.isTyping(at: receivedAt))
    }
}
