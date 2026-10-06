import Foundation

struct ChatSession {
    private let store: any ConversationStore
    private let localIP: String
    private let ownIPs: Set<String>
    private var messaging: MessagingService
    private var factory: MessageFactory
    private var presence: PresenceService
    private(set) var peerIP: String?

    init(role: PresenceService.Role, localIP: String, ownIPs: Set<String>, store: any ConversationStore) throws {
        self.store = store
        self.localIP = localIP
        self.ownIPs = ownIPs.union([localIP])
        let records = try store.load()
        messaging = MessagingService(messages: records.map(\.message))
        factory = MessageFactory(lastCreatedAt: records.filter(\.isOutgoing).map(\.message.identity.createdAt).max())
        presence = PresenceService(role: role)
        peerIP = records.last(where: { !$0.isOutgoing })?.message.identity.senderIP
    }

    mutating func prepareSend(content: String, at now: Date, contentHash: String) throws -> (ChatMessage, MessageTransmissionPlan) {
        let message = factory.create(content: content, senderIP: localIP, at: now, contentHash: contentHash)
        try store.append(RecordedMessage(message: message, isOutgoing: true))
        let plan = messaging.prepareSend(message, at: now)!
        return (message, plan)
    }

    mutating func receiveMessage(_ message: ChatMessage) throws -> RecordedMessage? {
        guard !ownIPs.contains(message.identity.senderIP) else { return nil }
        let record = RecordedMessage(message: message, isOutgoing: false)
        try store.append(record)
        peerIP = message.identity.senderIP
        // 반복 수신본이 아닌 새 메시지가 왔을 때만 입력 중 표시를 끝냅니다.
        guard messaging.receive(message) != nil else { return nil }
        presence.clearPeerTyping()
        return record
    }

    mutating func receiveHeartbeat(from ip: String, at now: Date) {
        guard !ownIPs.contains(ip) else { return }
        peerIP = ip
        presence.receiveHeartbeat(at: now)
    }

    mutating func receiveTyping(_ signal: TypingSignal, from ip: String, at now: Date) {
        guard !ownIPs.contains(ip) else { return }
        presence.receiveTyping(signal, at: now)
    }

    mutating func refreshHistory() throws -> [RecordedMessage] {
        var added: [RecordedMessage] = []
        for record in try store.load() {
            guard messaging.receive(record.message) != nil else { continue }
            if !record.isOutgoing { presence.clearPeerTyping() }
            added.append(record)
        }
        return added
    }

    func isPeerOnline(at now: Date) -> Bool { presence.isPeerOnline(at: now) }
    func shouldSendHeartbeat(at now: Date) -> Bool { presence.shouldSendHeartbeat(at: now) }
    mutating func recordHeartbeatSent(at now: Date) { presence.recordHeartbeatSent(at: now) }
    func isPeerTyping(at now: Date) -> Bool { presence.isPeerTyping(at: now) }
    func typingSignal(composing: Bool, at now: Date) -> TypingSignal? { presence.typingSignal(composing: composing, at: now) }
    mutating func recordTypingSent(_ signal: TypingSignal, at now: Date) { presence.recordTypingSent(signal, at: now) }
}
