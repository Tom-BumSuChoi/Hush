import Foundation
import Testing
@testable import Hush

struct MessagingServiceTests {
    @Test func 송신을_준비하면_메시지는_한_번_기록되고_세_번의_전송이_계획된다() {
        // Given: 빈 대화와 새로 보낼 메시지가 있습니다.
        var service = MessagingService()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let message = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: createdAt,
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        let startedAt = createdAt.addingTimeInterval(5)

        // When: 송신 시작 시각에 메시지 송신을 준비합니다.
        let plan = service.prepareSend(message, at: startedAt)

        // Then: 메시지는 한 번 기록되고 동일한 식별값으로 세 번 전송하도록 계획됩니다.
        #expect(service.messages == [message])
        #expect(plan?.transmissions.map(\.identity) == [
            message.identity, message.identity, message.identity,
        ])
        #expect(plan?.transmissions.map(\.scheduledAt) == [
            startedAt,
            startedAt.addingTimeInterval(0.5),
            startedAt.addingTimeInterval(1),
        ])
    }

    @Test func 같은_메시지의_송신을_다시_준비해도_추가_전송_계획은_생기지_않는다() {
        // Given: 새로 보낼 메시지가 있습니다.
        var service = MessagingService()
        let now = Date(timeIntervalSince1970: 1_000)
        let message = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: now,
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )

        // When: 같은 메시지의 송신을 두 번 준비합니다.
        let firstPlan = service.prepareSend(message, at: now)
        let secondPlan = service.prepareSend(message, at: now.addingTimeInterval(1))

        // Then: 첫 번째만 전송 계획을 반환하고 메시지는 한 번만 기록됩니다.
        #expect(firstPlan != nil)
        #expect(secondPlan == nil)
        #expect(service.messages == [message])
    }

    @Test func 같은_메시지를_세_번_수신해도_표시할_메시지는_한_번만_반환된다() {
        // Given: 빈 대화와 상대가 반복 전송한 메시지가 있습니다.
        var service = MessagingService()
        let message = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.35",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )

        // When: 같은 메시지를 세 번 수신합니다.
        let firstReceived = service.receive(message)
        let secondReceived = service.receive(message)
        let thirdReceived = service.receive(message)

        // Then: 처음 받은 메시지만 표시 대상으로 반환하고 기록도 한 건입니다.
        #expect(firstReceived == message)
        #expect(secondReceived == nil)
        #expect(thirdReceived == nil)
        #expect(service.messages == [message])
    }

    @Test func 내가_보낸_메시지를_다시_수신해도_표시_대상과_기록이_추가되지_않는다() {
        // Given: 내 메시지의 송신을 준비해 대화에 기록했습니다.
        var service = MessagingService()
        let now = Date(timeIntervalSince1970: 1_000)
        let message = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: now,
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        _ = service.prepareSend(message, at: now)

        // When: 내가 보낸 메시지를 다시 수신합니다.
        let received = service.receive(message)

        // Then: 중복이므로 표시 대상을 반환하지 않고 기록도 한 건입니다.
        #expect(received == nil)
        #expect(service.messages == [message])
    }

    @Test func 내가_보낸_내용과_같아도_상대의_새_메시지는_기록되고_반환된다() {
        // Given: 내 메시지가 기록된 대화와 상대가 새로 보낸 메시지가 있습니다.
        var service = MessagingService()
        let now = Date(timeIntervalSince1970: 1_000)
        let outgoing = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: now,
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        _ = service.prepareSend(outgoing, at: now)
        let incoming = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.35",
                createdAt: now,
                contentHash: "hash-1"
            ),
            content: outgoing.content
        )

        // When: 상대의 메시지를 수신합니다.
        let received = service.receive(incoming)

        // Then: 새 메시지는 표시 대상으로 반환되고 내 메시지와 함께 기록됩니다.
        #expect(received == incoming)
        #expect(service.messages == [outgoing, incoming])
    }

    @Test func 기존_대화로_시작하면_기록된_메시지를_다시_수신해도_추가되지_않는다() {
        // Given: 기존 메시지로 대화를 복원해 시작했습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.35",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        var service = MessagingService(messages: [recorded])

        // When: 기록된 메시지를 다시 수신합니다.
        let received = service.receive(recorded)

        // Then: 표시 대상과 기록이 추가되지 않습니다.
        #expect(received == nil)
        #expect(service.messages == [recorded])
    }

    @Test func 기존_대화로_시작해도_새_메시지는_수신할_수_있다() {
        // Given: 기존 대화를 복원해 시작했고 새 메시지가 있습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        var service = MessagingService(messages: [recorded])
        let incoming = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.35",
                createdAt: recorded.identity.createdAt.addingTimeInterval(1),
                contentHash: "hash-2"
            ),
            content: "네, 확인했습니다"
        )

        // When: 새 메시지를 수신합니다.
        let received = service.receive(incoming)

        // Then: 표시 대상으로 반환되고 기존 기록 뒤에 추가됩니다.
        #expect(received == incoming)
        #expect(service.messages == [recorded, incoming])
    }

    @Test func 기존_기록의_같은_메시지를_송신하려_해도_추가_계획은_생기지_않는다() {
        // Given: 기존에 기록한 내 메시지로 대화를 복원해 시작했습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        var service = MessagingService(messages: [recorded])

        // When: 같은 메시지의 송신을 다시 준비합니다.
        let plan = service.prepareSend(recorded, at: recorded.identity.createdAt.addingTimeInterval(5))

        // Then: 추가 전송 계획이 생기지 않고 기존 기록 한 건만 남습니다.
        #expect(plan == nil)
        #expect(service.messages == [recorded])
    }
}
