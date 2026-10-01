import Foundation

struct PeerPresence {
    private static let offlineThreshold: TimeInterval = 12
    private var lastHeartbeatReceivedAt: Date?

    mutating func receiveHeartbeat(at receivedAt: Date) {
        lastHeartbeatReceivedAt = receivedAt
    }

    func isOnline(at now: Date) -> Bool {
        guard let lastHeartbeatReceivedAt else {
            return false
        }

        return now.timeIntervalSince(lastHeartbeatReceivedAt) < Self.offlineThreshold
    }
}
