import Foundation

struct PresenceService {
    enum Role {
        case chat
        case backgroundReceiver
    }

    private let role: Role
    private var schedule = HeartbeatSchedule()
    private var peer = PeerPresence()

    init(role: Role) {
        self.role = role
    }

    func shouldSendHeartbeat(at now: Date) -> Bool {
        role == .chat && schedule.shouldSendHeartbeat(at: now)
    }

    mutating func recordHeartbeatSent(at sentAt: Date) {
        schedule.recordHeartbeatSent(at: sentAt)
    }

    mutating func receiveHeartbeat(at receivedAt: Date) {
        peer.receiveHeartbeat(at: receivedAt)
    }

    func isPeerOnline(at now: Date) -> Bool {
        peer.isOnline(at: now)
    }
}
