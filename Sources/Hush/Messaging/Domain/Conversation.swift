struct Conversation {
    private(set) var messages: [ChatMessage] = []
    private var deduplicator = MessageDeduplicator()

    init(messages: [ChatMessage] = []) {
        for message in messages {
            _ = record(message)
        }
    }

    mutating func record(_ message: ChatMessage) -> Bool {
        guard deduplicator.register(message.identity) else {
            return false
        }

        messages.append(message)
        return true
    }
}
