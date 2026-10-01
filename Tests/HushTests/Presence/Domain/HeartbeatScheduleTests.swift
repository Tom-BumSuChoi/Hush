import Foundation
import Testing
@testable import Hush

struct HeartbeatScheduleTests {
    @Test func heartbeat를_보낸_적이_없으면_즉시_보낼_때이다() {
        // Given: 채팅을 시작했고 아직 heartbeat를 보내지 않았습니다.
        let schedule = HeartbeatSchedule()
        let now = Date(timeIntervalSince1970: 1_000)

        // When: 시작 시각에 heartbeat를 보낼 때인지 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: now)

        // Then: 첫 heartbeat는 즉시 보낼 때입니다.
        #expect(shouldSend)
    }

    @Test func 첫_heartbeat를_보내면_같은_시각에는_다시_보내지_않는다() {
        // Given: 채팅 시작 시각에 첫 heartbeat를 보냈습니다.
        var schedule = HeartbeatSchedule()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordHeartbeatSent(at: startedAt)

        // When: 같은 시각에 heartbeat를 보낼 때인지 다시 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: startedAt)

        // Then: 첫 heartbeat를 이미 보냈으므로 다시 보낼 때가 아닙니다.
        #expect(!shouldSend)
    }

    @Test func heartbeat를_보낸_후_3초_직전에는_다시_보낼_때가_아니다() {
        // Given: heartbeat를 한 번 보냈습니다.
        var schedule = HeartbeatSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordHeartbeatSent(at: sentAt)

        // When: 마지막 송신으로부터 2.999초 후에 송신 시점인지 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: sentAt.addingTimeInterval(2.999))

        // Then: 아직 3초가 지나지 않았으므로 다시 보낼 때가 아닙니다.
        #expect(!shouldSend)
    }

    @Test func heartbeat를_보낸_후_정확히_3초가_지나면_다시_보낼_때이다() {
        // Given: heartbeat를 한 번 보냈습니다.
        var schedule = HeartbeatSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordHeartbeatSent(at: sentAt)

        // When: 마지막 송신으로부터 정확히 3초 후에 송신 시점인지 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: sentAt.addingTimeInterval(3))

        // Then: heartbeat를 다시 보낼 때입니다.
        #expect(shouldSend)
    }

    @Test func heartbeat를_보낸_후_3초를_초과하면_다시_보낼_때이다() {
        // Given: heartbeat를 한 번 보냈습니다.
        var schedule = HeartbeatSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordHeartbeatSent(at: sentAt)

        // When: 마지막 송신으로부터 4초 후에 송신 시점인지 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: sentAt.addingTimeInterval(4))

        // Then: heartbeat를 다시 보낼 때입니다.
        #expect(shouldSend)
    }

    @Test func 송신_시점을_확인해도_heartbeat를_보내기_전까지_송신_시점이_유지된다() {
        // Given: heartbeat를 보내고 3초가 지났습니다.
        var schedule = HeartbeatSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordHeartbeatSent(at: sentAt)
        let now = sentAt.addingTimeInterval(3)
        #expect(schedule.shouldSendHeartbeat(at: now))

        // When: 실제로 보내지 않고 같은 시각에 송신 시점을 다시 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: now)

        // Then: 여전히 heartbeat를 보낼 때입니다.
        #expect(shouldSend)
    }

    @Test func heartbeat를_다시_보내면_다음_송신까지_3초를_기다린다() {
        // Given: heartbeat를 보내고 3초 후에 다시 보냈습니다.
        var schedule = HeartbeatSchedule()
        let firstSentAt = Date(timeIntervalSince1970: 1_000)
        let lastSentAt = firstSentAt.addingTimeInterval(3)
        schedule.recordHeartbeatSent(at: firstSentAt)
        schedule.recordHeartbeatSent(at: lastSentAt)

        // When: 마지막 송신으로부터 2.999초 후에 송신 시점인지 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: lastSentAt.addingTimeInterval(2.999))

        // Then: 아직 다음 heartbeat를 보낼 때가 아닙니다.
        #expect(!shouldSend)
    }

    @Test func heartbeat를_다시_보내면_마지막_송신으로부터_3초_후에_다시_보낼_때이다() {
        // Given: heartbeat를 보내고 9초 후에 다시 보냈습니다.
        var schedule = HeartbeatSchedule()
        let firstSentAt = Date(timeIntervalSince1970: 1_000)
        let lastSentAt = firstSentAt.addingTimeInterval(9)
        schedule.recordHeartbeatSent(at: firstSentAt)
        schedule.recordHeartbeatSent(at: lastSentAt)

        // When: 마지막 송신으로부터 정확히 3초 후에 송신 시점인지 확인합니다.
        let shouldSend = schedule.shouldSendHeartbeat(at: lastSentAt.addingTimeInterval(3))

        // Then: heartbeat를 다시 보낼 때입니다.
        #expect(shouldSend)
    }
}
