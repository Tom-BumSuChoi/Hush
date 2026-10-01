struct RecordedMessage: Codable, Equatable, Sendable {
    let message: ChatMessage
    let isOutgoing: Bool
}
