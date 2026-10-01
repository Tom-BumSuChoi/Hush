protocol ConversationStore {
    func load() throws -> [RecordedMessage]
    @discardableResult func append(_ record: RecordedMessage) throws -> Bool
}
