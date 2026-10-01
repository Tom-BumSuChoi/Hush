struct ChatMessage: Equatable, Codable, Sendable {
    let identity: MessageIdentity
    let content: String
}
