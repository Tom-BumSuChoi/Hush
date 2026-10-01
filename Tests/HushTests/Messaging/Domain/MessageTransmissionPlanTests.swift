import Foundation
import Testing
@testable import Hush

struct MessageTransmissionPlanTests {
    @Test func 메시지_하나의_송신_계획은_정확히_세_번이다() {
        // Given: 새로 보낼 메시지의 식별값과 송신 시작 시각이 있습니다.
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let identity = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: startedAt,
            contentHash: "hash-1"
        )

        // When: 메시지의 반복 송신 계획을 만듭니다.
        let plan = MessageTransmissionPlan(identity: identity, startedAt: startedAt)

        // Then: 송신은 정확히 세 번 계획됩니다.
        #expect(plan.transmissions.count == 3)
    }

    @Test func 송신은_시작_시점과_0점5초_후와_1초_후에_계획된다() {
        // Given: 새로 보낼 메시지의 식별값과 송신 시작 시각이 있습니다.
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let identity = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: startedAt,
            contentHash: "hash-1"
        )

        // When: 메시지의 반복 송신 계획을 만듭니다.
        let plan = MessageTransmissionPlan(identity: identity, startedAt: startedAt)
        let scheduledTimes = plan.transmissions.map(\.scheduledAt)

        // Then: 시작 시점, 0.5초 후, 1초 후에 한 번씩 송신하도록 계획됩니다.
        #expect(scheduledTimes == [
            startedAt,
            startedAt.addingTimeInterval(0.5),
            startedAt.addingTimeInterval(1),
        ])
    }

    @Test func 세_번의_송신은_같은_메시지_식별값을_유지한다() {
        // Given: 최초 생성 시각과 내용 해시가 정해진 메시지가 있습니다.
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let identity = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: createdAt,
            contentHash: "hash-1"
        )

        // When: 생성 시각보다 늦게 시작하는 반복 송신 계획을 만듭니다.
        let plan = MessageTransmissionPlan(
            identity: identity,
            startedAt: createdAt.addingTimeInterval(5)
        )
        let identities = plan.transmissions.map(\.identity)

        // Then: 세 번 모두 발신 IP, 최초 생성 시각, 내용 해시를 유지합니다.
        #expect(identities == [identity, identity, identity])
    }

    @Test func 송신_시작이_늦어져도_송신_시작_시각을_기준으로_계획된다() {
        // Given: 생성 후 5초가 지난 메시지를 보내려고 합니다.
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let startedAt = createdAt.addingTimeInterval(5)
        let identity = MessageIdentity(
            senderIP: "192.168.0.34",
            createdAt: createdAt,
            contentHash: "hash-1"
        )

        // When: 메시지의 반복 송신 계획을 만듭니다.
        let plan = MessageTransmissionPlan(identity: identity, startedAt: startedAt)
        let scheduledTimes = plan.transmissions.map(\.scheduledAt)

        // Then: 생성 시각이 아닌 송신 시작 시각부터 1초 동안 송신하도록 계획됩니다.
        #expect(scheduledTimes == [
            startedAt,
            startedAt.addingTimeInterval(0.5),
            startedAt.addingTimeInterval(1),
        ])
    }
}
