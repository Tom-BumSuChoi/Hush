import Foundation
import Testing
@testable import Hush

struct MessageDeduplicatorTests {
    @Test func 처음_받은_메시지는_새_메시지로_등록된다() {
        // Given: 등록된 메시지가 없는 중복 판별기가 있습니다.
        var deduplicator = MessageDeduplicator()
        let identity = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )

        // When: 처음 받은 메시지의 식별값을 등록합니다.
        let isNewMessage = deduplicator.register(identity)

        // Then: 새 메시지로 등록됩니다.
        #expect(isNewMessage)
    }

    @Test func 같은_메시지를_세_번_받으면_첫_번째만_새_메시지로_등록된다() {
        // Given: 등록된 메시지가 없는 중복 판별기와 반복 전송할 식별값이 있습니다.
        var deduplicator = MessageDeduplicator()
        let identity = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )

        // When: 같은 메시지의 식별값을 세 번 등록합니다.
        let firstIsNew = deduplicator.register(identity)
        let secondIsNew = deduplicator.register(identity)
        let thirdIsNew = deduplicator.register(identity)

        // Then: 첫 번째만 새 메시지이고 나머지는 중복입니다.
        #expect(firstIsNew)
        #expect(!secondIsNew)
        #expect(!thirdIsNew)
    }

    @Test func 같은_시각의_같은_내용이라도_발신_IP가_다르면_새_메시지로_등록된다() {
        // Given: 첫 번째 발신자의 메시지가 이미 등록되어 있습니다.
        var deduplicator = MessageDeduplicator()
        let original = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        _ = deduplicator.register(original)
        let otherSender = MessageIdentity(
            senderIP: "192.168.0.35",
            createdAt: original.createdAt,
            contentHash: original.contentHash
        )

        // When: 다른 발신자가 보낸 메시지의 식별값을 등록합니다.
        let isNewMessage = deduplicator.register(otherSender)

        // Then: 발신 IP가 다르므로 새 메시지로 등록됩니다.
        #expect(isNewMessage)
    }

    @Test func 같은_발신자가_같은_내용을_나중에_보내면_새_메시지로_등록된다() {
        // Given: 첫 번째 메시지가 이미 등록되어 있습니다.
        var deduplicator = MessageDeduplicator()
        let original = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        _ = deduplicator.register(original)
        let laterMessage = MessageIdentity(
            senderIP: original.senderIP,
            createdAt: original.createdAt.addingTimeInterval(1),
            contentHash: original.contentHash
        )

        // When: 나중에 새로 보낸 메시지의 식별값을 등록합니다.
        let isNewMessage = deduplicator.register(laterMessage)

        // Then: 최초 생성 시각이 다르므로 새 메시지로 등록됩니다.
        #expect(isNewMessage)
    }

    @Test func 발신_IP와_생성_시각이_같아도_내용_해시가_다르면_새_메시지로_등록된다() {
        // Given: 첫 번째 메시지가 이미 등록되어 있습니다.
        var deduplicator = MessageDeduplicator()
        let original = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        _ = deduplicator.register(original)
        let differentContent = MessageIdentity(
            senderIP: original.senderIP,
            createdAt: original.createdAt,
            contentHash: "hash-2"
        )

        // When: 내용 해시가 다른 메시지의 식별값을 등록합니다.
        let isNewMessage = deduplicator.register(differentContent)

        // Then: 내용 해시가 다르므로 새 메시지로 등록됩니다.
        #expect(isNewMessage)
    }

    @Test func 다른_메시지_뒤에_이전_메시지를_다시_받아도_중복이다() {
        // Given: 서로 다른 두 메시지가 차례로 등록되어 있습니다.
        var deduplicator = MessageDeduplicator()
        let first = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        let second = MessageIdentity(
            senderIP: first.senderIP,
            createdAt: first.createdAt.addingTimeInterval(1),
            contentHash: "hash-2"
        )
        _ = deduplicator.register(first)
        _ = deduplicator.register(second)

        // When: 첫 번째 메시지의 식별값을 다시 등록합니다.
        let isNewMessage = deduplicator.register(first)

        // Then: 이전 메시지도 기억하고 있으므로 중복입니다.
        #expect(!isNewMessage)
    }

    @Test func 기록의_식별값으로_복원하면_기존_메시지는_중복이다() {
        // Given: 대화 기록에 있는 식별값으로 중복 판별기를 복원했습니다.
        let recorded = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        var deduplicator = MessageDeduplicator(knownIdentities: [recorded])
        let received = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )

        // When: 기록과 같은 메시지의 식별값을 등록합니다.
        let isNewMessage = deduplicator.register(received)

        // Then: 기존 기록의 메시지이므로 중복입니다.
        #expect(!isNewMessage)
    }

    @Test func 기록의_식별값으로_복원해도_새_메시지는_등록된다() {
        // Given: 대화 기록에 있는 식별값으로 중복 판별기를 복원했습니다.
        let recorded = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        var deduplicator = MessageDeduplicator(knownIdentities: [recorded])
        let newMessage = MessageIdentity(
            senderIP: recorded.senderIP,
            createdAt: recorded.createdAt.addingTimeInterval(1),
            contentHash: recorded.contentHash
        )

        // When: 기록에 없는 메시지의 식별값을 등록합니다.
        let isNewMessage = deduplicator.register(newMessage)

        // Then: 새 메시지로 등록됩니다.
        #expect(isNewMessage)
    }
}
