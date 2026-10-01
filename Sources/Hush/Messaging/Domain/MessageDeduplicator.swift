struct MessageDeduplicator {
    private var knownIdentities: Set<MessageIdentity>

    init(knownIdentities: [MessageIdentity] = []) {
        self.knownIdentities = Set(knownIdentities)
    }

    mutating func register(_ identity: MessageIdentity) -> Bool {
        knownIdentities.insert(identity).inserted
    }
}
