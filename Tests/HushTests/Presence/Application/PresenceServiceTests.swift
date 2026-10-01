import Foundation
import Testing
@testable import Hush

struct PresenceServiceTests {
    @Test func 채팅용_역할로_시작하면_첫_heartbeat를_즉시_보낼_때이다() {
        // Given: 채팅용 역할로 시작했고 아직 heartbeat를 보내지 않았습니다.
        let service = PresenceService(role: .chat)
        let now = Date(timeIntervalSince1970: 1_000)

        // When: 시작 시각에 heartbeat 송신 여부를 확인합니다.
        let shouldSend = service.shouldSendHeartbeat(at: now)

        // Then: 첫 heartbeat를 즉시 보낼 때입니다.
        #expect(shouldSend)
    }

    @Test func 백그라운드_수신기_역할은_시간이_지나도_heartbeat를_보내지_않는다() {
        // Given: 백그라운드 수신기 역할로 시작했습니다.
        let service = PresenceService(role: .backgroundReceiver)
        let startedAt = Date(timeIntervalSince1970: 1_000)

        // When: 시작 시각과 30초 후의 heartbeat 송신 여부를 확인합니다.
        let shouldSendInitially = service.shouldSendHeartbeat(at: startedAt)
        let shouldSendLater = service.shouldSendHeartbeat(at: startedAt.addingTimeInterval(30))

        // Then: 수신기만 실행 중인 상태를 온라인으로 알리지 않습니다.
        #expect(!shouldSendInitially)
        #expect(!shouldSendLater)
    }

    @Test func 채팅용_역할은_마지막_heartbeat_송신_후_3초부터_다시_보낼_때이다() {
        // Given: 채팅용 역할에서 heartbeat를 보냈습니다.
        var service = PresenceService(role: .chat)
        let sentAt = Date(timeIntervalSince1970: 1_000)
        service.recordHeartbeatSent(at: sentAt)

        // When: 마지막 송신 후 3초 직전과 정확히 3초에 송신 여부를 확인합니다.
        let shouldSendBefore = service.shouldSendHeartbeat(at: sentAt.addingTimeInterval(2.999))
        let shouldSendAtBoundary = service.shouldSendHeartbeat(at: sentAt.addingTimeInterval(3))

        // Then: 3초가 지난 시점부터 다음 heartbeat를 보낼 때입니다.
        #expect(!shouldSendBefore)
        #expect(shouldSendAtBoundary)
    }

    @Test func 송신_여부를_확인해도_실제로_보내기_전에는_송신_시점이_유지된다() {
        // Given: 채팅용 역할에서 아직 첫 heartbeat를 보내지 않았습니다.
        var service = PresenceService(role: .chat)
        let now = Date(timeIntervalSince1970: 1_000)

        // When: 송신 여부를 두 번 확인한 다음 실제 송신 시각을 기록합니다.
        let firstCheck = service.shouldSendHeartbeat(at: now)
        let secondCheck = service.shouldSendHeartbeat(at: now)
        service.recordHeartbeatSent(at: now)
        let afterSending = service.shouldSendHeartbeat(at: now)

        // Then: 조회만으로 송신 시각이 바뀌지 않고 실제 송신 후에만 대기합니다.
        #expect(firstCheck)
        #expect(secondCheck)
        #expect(!afterSending)
    }

    @Test func 상대의_heartbeat를_받으면_12초_미수신_시점부터_오프라인이다() {
        // Given: 채팅용 역할로 시작했고 상대는 아직 오프라인입니다.
        var service = PresenceService(role: .chat)
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        #expect(!service.isPeerOnline(at: receivedAt))

        // When: 상대의 heartbeat를 수신합니다.
        service.receiveHeartbeat(at: receivedAt)

        // Then: 수신 후에는 온라인이고 추가 수신 없이 12초가 지나면 오프라인입니다.
        #expect(service.isPeerOnline(at: receivedAt))
        #expect(service.isPeerOnline(at: receivedAt.addingTimeInterval(11.999)))
        #expect(!service.isPeerOnline(at: receivedAt.addingTimeInterval(12)))
    }

    @Test func 오프라인인_상대의_heartbeat를_다시_받으면_온라인으로_돌아온다() {
        // Given: 상대의 마지막 heartbeat 수신 후 15초가 지났습니다.
        var service = PresenceService(role: .chat)
        let firstReceivedAt = Date(timeIntervalSince1970: 1_000)
        service.receiveHeartbeat(at: firstReceivedAt)
        let now = firstReceivedAt.addingTimeInterval(15)
        #expect(!service.isPeerOnline(at: now))

        // When: 상대의 heartbeat를 다시 수신합니다.
        service.receiveHeartbeat(at: now)

        // Then: 상대는 다시 온라인입니다.
        #expect(service.isPeerOnline(at: now))
    }

    @Test func 백그라운드_수신기가_상대의_heartbeat를_받아도_내_heartbeat는_보내지_않는다() {
        // Given: 백그라운드 수신기 역할로 시작했습니다.
        var service = PresenceService(role: .backgroundReceiver)
        let receivedAt = Date(timeIntervalSince1970: 1_000)

        // When: 상대의 heartbeat를 수신합니다.
        service.receiveHeartbeat(at: receivedAt)

        // Then: 상대 상태는 갱신하지만 내 역할의 heartbeat 송신은 허용하지 않습니다.
        #expect(service.isPeerOnline(at: receivedAt))
        #expect(!service.shouldSendHeartbeat(at: receivedAt))
        #expect(!service.shouldSendHeartbeat(at: receivedAt.addingTimeInterval(3)))
    }

    @Test func 내_heartbeat를_보내도_상대가_온라인으로_바뀌지_않는다() {
        // Given: 상대의 heartbeat를 받은 적이 없는 채팅용 역할입니다.
        var service = PresenceService(role: .chat)
        let sentAt = Date(timeIntervalSince1970: 1_000)

        // When: 내 heartbeat의 송신 시각을 기록합니다.
        service.recordHeartbeatSent(at: sentAt)

        // Then: 내 송신으로 상대의 온라인 상태를 추정하지 않습니다.
        #expect(!service.isPeerOnline(at: sentAt))
    }

    @Test func 상대의_heartbeat를_받아도_내_다음_heartbeat_송신_시점은_늦춰지지_않는다() {
        // Given: 채팅용 역할에서 내 heartbeat를 보냈습니다.
        var service = PresenceService(role: .chat)
        let sentAt = Date(timeIntervalSince1970: 1_000)
        service.recordHeartbeatSent(at: sentAt)

        // When: 내 송신 후 2초에 상대의 heartbeat를 수신합니다.
        service.receiveHeartbeat(at: sentAt.addingTimeInterval(2))

        // Then: 내 송신으로부터 3초에 다음 heartbeat를 보낼 때입니다.
        #expect(service.shouldSendHeartbeat(at: sentAt.addingTimeInterval(3)))
    }
}
