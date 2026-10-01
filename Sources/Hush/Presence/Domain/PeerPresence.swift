import Foundation

struct PeerPresence {
    private var lastHeartbeatReceivedAt: Date?

    mutating func receiveHeartbeat(at receivedAt: Date) {
        lastHeartbeatReceivedAt = receivedAt
    }

    func isOnline(at now: Date) -> Bool {
        guard let lastHeartbeatReceivedAt else {
            return false
        }

        return now.timeIntervalSince(lastHeartbeatReceivedAt) < HushConfig.peerOfflineThreshold
    }
}
