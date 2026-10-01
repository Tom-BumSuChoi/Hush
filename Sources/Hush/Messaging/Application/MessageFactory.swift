import Foundation

struct MessageFactory {
    private var lastCreatedAt: Date?

    init(lastCreatedAt: Date? = nil) {
        self.lastCreatedAt = lastCreatedAt
    }

    mutating func create(content: String, senderIP: String, at now: Date, contentHash: String) -> ChatMessage {
        let createdAt = lastCreatedAt.map { max(now, $0.addingTimeInterval(0.000001)) } ?? now
        lastCreatedAt = createdAt
        return ChatMessage(
            identity: MessageIdentity(senderIP: senderIP, createdAt: createdAt, contentHash: contentHash),
            content: content
        )
    }
}
