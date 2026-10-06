import Foundation

struct PresenceService {
    enum Role {
        case chat
        case backgroundReceiver
    }

    private let role: Role
    private var schedule = HeartbeatSchedule()
    private var peer = PeerPresence()
    private var typingSchedule = TypingSchedule()
    private var peerTyping = PeerTyping()

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

    func typingSignal(composing: Bool, at now: Date) -> TypingSignal? {
        role == .chat ? typingSchedule.signal(composing: composing, at: now) : nil
    }

    mutating func recordTypingSent(_ signal: TypingSignal, at sentAt: Date) {
        typingSchedule.recordSent(signal, at: sentAt)
    }

    mutating func receiveTyping(_ signal: TypingSignal, at receivedAt: Date) {
        peerTyping.receive(signal, at: receivedAt)
    }

    mutating func clearPeerTyping() {
        peerTyping.clear()
    }

    func isPeerTyping(at now: Date) -> Bool {
        peerTyping.isTyping(at: now)
    }
}
