import Foundation
import Testing
@testable import Hush

struct MessageSenderTests {
    @Test func 실제_UDP_송신은_시작과_0점5초와_1초에만_실행된다() throws {
        // Given: 로컬 수신 소켓과 동일한 암호화 패킷의 세 번 송신 계획이 있습니다.
        let receiver = try UDPTransport(port: 0, bindIP: "127.0.0.1")
        let socket = try UDPTransport(port: 0, bindIP: "127.0.0.1")
        let port = try receiver.localPort
        var sender = MessageSender { try socket.send($0, to: "127.0.0.1", port: port) }
        let identity = MessageIdentity(senderIP: "127.0.0.1", createdAt: Date(), contentHash: "hash")
        let packet = Data([1, 2, 3])
        sender.enqueue(packet, plan: MessageTransmissionPlan(identity: identity, startedAt: Date()), at: 100)
        // When: 실제 대기 없이 단조 시각의 각 경계에서 송신을 실행합니다.
        try sender.sendDue(at: 100)
        let first = try receiver.receive()
        try sender.sendDue(at: 100.499)
        let beforeSecond = try receiver.receive()
        try sender.sendDue(at: 100.5)
        let second = try receiver.receive()
        try sender.sendDue(at: 100.999)
        let beforeThird = try receiver.receive()
        try sender.sendDue(at: 101)
        let third = try receiver.receive()
        try sender.sendDue(at: 110)
        let after = try receiver.receive()
        // Then: 같은 패킷을 정확히 세 번 보내고 이후 송신은 끝납니다.
        #expect(first?.data == packet)
        #expect(beforeSecond == nil)
        #expect(second?.data == packet)
        #expect(beforeThird == nil)
        #expect(third?.data == packet)
        #expect(after == nil)
        #expect(!sender.hasPending)
    }

    @Test func 소켓_송신이_실패해도_해당_송신을_무한히_재시도하지_않는다() throws {
        // Given: 소켓 송신에 실패하는 송신기가 있습니다.
        enum SendFailure: Error { case unavailable }
        var attempts = 0
        var sender = MessageSender { _ in attempts += 1; throw SendFailure.unavailable }
        let identity = MessageIdentity(senderIP: "127.0.0.1", createdAt: Date(), contentHash: "hash")
        sender.enqueue(Data([1]), plan: MessageTransmissionPlan(identity: identity, startedAt: Date()), at: 100)
        // When: 같은 시작 시각에 송신을 두 번 확인합니다.
        #expect(throws: SendFailure.unavailable) { try sender.sendDue(at: 100) }
        try sender.sendDue(at: 100)
        // Then: 실패한 송신을 추가 재전송하지 않고 다음 예정 시각을 유지합니다.
        #expect(attempts == 1)
        #expect(sender.nextDeadline == 100.5)
    }
}
