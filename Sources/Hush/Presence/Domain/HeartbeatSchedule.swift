import Foundation

struct HeartbeatSchedule {
    private var lastHeartbeatSentAt: Date?

    mutating func recordHeartbeatSent(at sentAt: Date) {
        lastHeartbeatSentAt = sentAt
    }

    func shouldSendHeartbeat(at now: Date) -> Bool {
        guard let lastHeartbeatSentAt else {
            return true
        }

        return now.timeIntervalSince(lastHeartbeatSentAt) >= HushConfig.heartbeatInterval
    }
}
