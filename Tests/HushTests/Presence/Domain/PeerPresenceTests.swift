import Foundation
import Testing
@testable import Hush

struct PeerPresenceTests {
    @Test func heartbeat를_받은_적이_없으면_오프라인이다() {
        // Given: heartbeat를 받은 적이 없는 상대가 있습니다.
        let peer = PeerPresence()
        let now = Date(timeIntervalSince1970: 1_000)

        // When: 현재 시각에 상대의 온라인 여부를 확인합니다.
        let isOnline = peer.isOnline(at: now)

        // Then: 상대는 오프라인입니다.
        #expect(!isOnline)
    }

    @Test func heartbeat를_받으면_온라인이다() {
        // Given: heartbeat를 받은 적이 없는 상대가 있습니다.
        var peer = PeerPresence()
        let receivedAt = Date(timeIntervalSince1970: 1_000)

        // When: 상대의 heartbeat를 받습니다.
        peer.receiveHeartbeat(at: receivedAt)

        // Then: 수신 시각에 상대는 온라인입니다.
        #expect(peer.isOnline(at: receivedAt))
    }

    @Test func 마지막_heartbeat_수신_후_12초_직전에는_온라인이다() {
        // Given: 상대의 heartbeat를 한 번 받았습니다.
        var peer = PeerPresence()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receiveHeartbeat(at: receivedAt)

        // When: 마지막 수신으로부터 11.999초 후에 온라인 여부를 확인합니다.
        let isOnline = peer.isOnline(at: receivedAt.addingTimeInterval(11.999))

        // Then: 아직 12초가 지나지 않았으므로 상대는 온라인입니다.
        #expect(isOnline)
    }

    @Test func 마지막_heartbeat_수신_후_정확히_12초가_지나면_오프라인이다() {
        // Given: 상대의 heartbeat를 한 번 받았습니다.
        var peer = PeerPresence()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receiveHeartbeat(at: receivedAt)

        // When: 추가 수신 없이 정확히 12초 후에 온라인 여부를 확인합니다.
        let isOnline = peer.isOnline(at: receivedAt.addingTimeInterval(12))

        // Then: 상대는 오프라인입니다.
        #expect(!isOnline)
    }

    @Test func 마지막_heartbeat_수신_후_12초를_초과하면_오프라인이다() {
        // Given: 상대의 heartbeat를 한 번 받았습니다.
        var peer = PeerPresence()
        let receivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receiveHeartbeat(at: receivedAt)

        // When: 추가 수신 없이 13초 후에 온라인 여부를 확인합니다.
        let isOnline = peer.isOnline(at: receivedAt.addingTimeInterval(13))

        // Then: 상대는 오프라인입니다.
        #expect(!isOnline)
    }

    @Test func heartbeat를_다시_받으면_마지막_수신_시각을_기준으로_온라인을_유지한다() {
        // Given: 첫 heartbeat를 받고 9초 후에 다음 heartbeat를 받았습니다.
        var peer = PeerPresence()
        let firstReceivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receiveHeartbeat(at: firstReceivedAt)
        peer.receiveHeartbeat(at: firstReceivedAt.addingTimeInterval(9))

        // When: 첫 수신으로부터 12초 후에 온라인 여부를 확인합니다.
        let isOnline = peer.isOnline(at: firstReceivedAt.addingTimeInterval(12))

        // Then: 마지막 수신으로부터는 3초만 지났으므로 상대는 온라인입니다.
        #expect(isOnline)
    }

    @Test func heartbeat를_다시_받아도_마지막_수신_후_12초가_지나면_오프라인이다() {
        // Given: 첫 heartbeat를 받고 9초 후에 다음 heartbeat를 받았습니다.
        var peer = PeerPresence()
        let firstReceivedAt = Date(timeIntervalSince1970: 1_000)
        let lastReceivedAt = firstReceivedAt.addingTimeInterval(9)
        peer.receiveHeartbeat(at: firstReceivedAt)
        peer.receiveHeartbeat(at: lastReceivedAt)

        // When: 마지막 수신으로부터 정확히 12초 후에 온라인 여부를 확인합니다.
        let isOnline = peer.isOnline(at: lastReceivedAt.addingTimeInterval(12))

        // Then: 상대는 오프라인입니다.
        #expect(!isOnline)
    }

    @Test func 오프라인인_상대의_heartbeat를_다시_받으면_온라인이다() {
        // Given: 마지막 heartbeat 수신 후 12초가 지나 상대가 오프라인입니다.
        var peer = PeerPresence()
        let firstReceivedAt = Date(timeIntervalSince1970: 1_000)
        peer.receiveHeartbeat(at: firstReceivedAt)
        let now = firstReceivedAt.addingTimeInterval(15)
        #expect(!peer.isOnline(at: now))

        // When: 상대의 heartbeat를 다시 받습니다.
        peer.receiveHeartbeat(at: now)

        // Then: 상대는 다시 온라인입니다.
        #expect(peer.isOnline(at: now))
    }
}
