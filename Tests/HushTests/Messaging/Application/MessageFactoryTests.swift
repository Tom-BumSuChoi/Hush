import Foundation
import Testing
@testable import Hush

struct MessageFactoryTests {
    @Test func 같은_시각에_같은_내용을_새로_작성해도_서로_다른_메시지이다() {
        // Given: 같은 시각과 내용을 전달하는 메시지 생성기가 있습니다.
        var factory = MessageFactory()
        let now = Date(timeIntervalSince1970: 1_000)
        // When: 같은 내용으로 두 메시지를 새로 작성합니다.
        let first = factory.create(content: "안녕", senderIP: "192.168.0.34", at: now, contentHash: "hash")
        let second = factory.create(content: "안녕", senderIP: "192.168.0.34", at: now, contentHash: "hash")
        // Then: 생성 시각이 증가해 중복 메시지로 취급하지 않습니다.
        #expect(first.identity != second.identity)
        #expect(second.identity.createdAt > first.identity.createdAt)
    }

    @Test func 재시작하거나_시계가_뒤로_가도_기존_메시지와_구분된다() {
        // Given: 기존 기록의 마지막 생성 시각을 복원했습니다.
        let last = Date(timeIntervalSince1970: 1_000)
        var factory = MessageFactory(lastCreatedAt: last)
        // When: 과거 시각으로 새 메시지를 작성합니다.
        let message = factory.create(content: "안녕", senderIP: "192.168.0.34", at: last.addingTimeInterval(-5), contentHash: "hash")
        // Then: 기존 메시지 이후의 시각으로 생성합니다.
        #expect(message.identity.createdAt > last)
    }
}
