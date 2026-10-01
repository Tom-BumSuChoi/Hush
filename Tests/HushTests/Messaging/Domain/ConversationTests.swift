import Foundation
import Testing
@testable import Hush

struct ConversationTests {
    @Test func 메시지를_기록하면_식별값과_내용을_조회할_수_있다() {
        // Given: 기록이 없는 대화와 새 메시지가 있습니다.
        var conversation = Conversation()
        let message = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )

        // When: 메시지를 대화에 기록합니다.
        let wasRecorded = conversation.record(message)

        // Then: 새로 기록되며 식별값과 내용을 그대로 조회할 수 있습니다.
        #expect(wasRecorded)
        #expect(conversation.messages == [message])
    }

    @Test func 같은_메시지를_세_번_기록해도_대화에는_한_건만_남는다() {
        // Given: 기록이 없는 대화와 반복 전송된 메시지가 있습니다.
        var conversation = Conversation()
        let message = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )

        // When: 같은 메시지를 세 번 기록합니다.
        let firstWasRecorded = conversation.record(message)
        let secondWasRecorded = conversation.record(message)
        let thirdWasRecorded = conversation.record(message)

        // Then: 첫 번째만 기록되며 대화에는 한 건만 남습니다.
        #expect(firstWasRecorded)
        #expect(!secondWasRecorded)
        #expect(!thirdWasRecorded)
        #expect(conversation.messages == [message])
    }

    @Test func 같은_내용을_나중에_새로_보내면_별도_기록으로_남는다() {
        // Given: 첫 메시지가 기록된 대화와 나중에 새로 보낸 메시지가 있습니다.
        var conversation = Conversation()
        let original = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        _ = conversation.record(original)
        let later = ChatMessage(
            identity: MessageIdentity(
                senderIP: original.identity.senderIP,
                createdAt: original.identity.createdAt.addingTimeInterval(1),
                contentHash: original.identity.contentHash
            ),
            content: original.content
        )

        // When: 나중에 새로 보낸 메시지를 기록합니다.
        let wasRecorded = conversation.record(later)

        // Then: 같은 내용이라도 최초 생성 시각이 달라 별도 기록으로 남습니다.
        #expect(wasRecorded)
        #expect(conversation.messages == [original, later])
    }

    @Test func 서로_다른_발신자의_같은_내용은_각각_기록된다() {
        // Given: 첫 발신자의 메시지가 기록된 대화와 다른 발신자의 메시지가 있습니다.
        var conversation = Conversation()
        let original = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        _ = conversation.record(original)
        let otherSender = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.35",
                createdAt: original.identity.createdAt,
                contentHash: original.identity.contentHash
            ),
            content: original.content
        )

        // When: 다른 발신자의 메시지를 기록합니다.
        let wasRecorded = conversation.record(otherSender)

        // Then: 같은 내용이라도 발신자가 달라 각각 기록됩니다.
        #expect(wasRecorded)
        #expect(conversation.messages == [original, otherSender])
    }

    @Test func 대화_기록을_복원하면_기존_메시지를_조회할_수_있다() {
        // Given: 기존 대화에 보관된 메시지가 있습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )

        // When: 기존 메시지로 대화 기록을 복원합니다.
        let conversation = Conversation(messages: [recorded])

        // Then: 기존 메시지의 식별값과 내용을 조회할 수 있습니다.
        #expect(conversation.messages == [recorded])
    }

    @Test func 대화_기록을_복원한_뒤_기존_메시지를_다시_받아도_추가되지_않는다() {
        // Given: 기존 메시지로 대화 기록을 복원했습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        var conversation = Conversation(messages: [recorded])

        // When: 기존 메시지를 다시 기록합니다.
        let wasRecorded = conversation.record(recorded)

        // Then: 중복이므로 추가되지 않고 기존 기록 한 건만 남습니다.
        #expect(!wasRecorded)
        #expect(conversation.messages == [recorded])
    }

    @Test func 복원할_기록에_같은_메시지가_여러_번_있어도_한_건만_남는다() {
        // Given: 복원할 기록에 같은 메시지가 세 번 들어 있습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )

        // When: 해당 기록으로 대화를 복원합니다.
        let conversation = Conversation(messages: [recorded, recorded, recorded])

        // Then: 같은 메시지는 한 건만 남습니다.
        #expect(conversation.messages == [recorded])
    }

    @Test func 대화_기록을_복원한_뒤_새_메시지를_추가할_수_있다() {
        // Given: 기존 대화를 복원했고 새 메시지가 있습니다.
        let recorded = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.34",
                createdAt: Date(timeIntervalSince1970: 1_000),
                contentHash: "hash-1"
            ),
            content: "안녕하세요"
        )
        var conversation = Conversation(messages: [recorded])
        let newMessage = ChatMessage(
            identity: MessageIdentity(
                senderIP: "192.168.0.35",
                createdAt: recorded.identity.createdAt.addingTimeInterval(1),
                contentHash: "hash-2"
            ),
            content: "네, 확인했습니다"
        )

        // When: 새 메시지를 대화에 기록합니다.
        let wasRecorded = conversation.record(newMessage)

        // Then: 기존 기록과 새 메시지를 함께 조회할 수 있습니다.
        #expect(wasRecorded)
        #expect(conversation.messages == [recorded, newMessage])
    }
}
