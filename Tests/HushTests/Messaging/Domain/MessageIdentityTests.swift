import Foundation
import Testing
@testable import Hush

struct MessageIdentityTests {
    @Test func 발신_IP와_최초_생성_시각과_내용_해시가_같으면_같은_메시지이다() {
        // Given: 발신 IP, 최초 생성 시각, 내용 해시가 같은 반복 전송본이 있습니다.
        let original = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        let retransmission = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )

        // When: 두 전송본의 메시지 식별값을 비교합니다.
        let isSameMessage = original == retransmission

        // Then: 두 전송본은 같은 메시지입니다.
        #expect(isSameMessage)
    }

    @Test func 생성_시각과_내용_해시가_같아도_발신_IP가_다르면_다른_메시지이다() {
        // Given: 서로 다른 발신자가 같은 시각에 같은 내용을 보냈습니다.
        let first = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        let second = MessageIdentity(
            senderIP: "192.168.0.35",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )

        // When: 두 메시지의 식별값을 비교합니다.
        let isSameMessage = first == second

        // Then: 발신자가 다르므로 다른 메시지입니다.
        #expect(!isSameMessage)
    }

    @Test func 발신_IP와_내용_해시가_같아도_최초_생성_시각이_다르면_다른_메시지이다() {
        // Given: 같은 발신자가 같은 내용을 나중에 새로 보냈습니다.
        let first = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        let second = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_001),
            contentHash: "hash-1"
        )

        // When: 두 메시지의 식별값을 비교합니다.
        let isSameMessage = first == second

        // Then: 최초 생성 시각이 다르므로 다른 메시지입니다.
        #expect(!isSameMessage)
    }

    @Test func 발신_IP와_생성_시각이_같아도_내용_해시가_다르면_다른_메시지이다() {
        // Given: 같은 발신자가 같은 시각에 내용 해시가 다른 메시지를 보냈습니다.
        let first = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-1"
        )
        let second = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash-2"
        )

        // When: 두 메시지의 식별값을 비교합니다.
        let isSameMessage = first == second

        // Then: 내용 해시가 다르므로 다른 메시지입니다.
        #expect(!isSameMessage)
    }
}
