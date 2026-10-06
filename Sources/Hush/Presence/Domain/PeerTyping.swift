import Foundation

struct PeerTyping {
    private var lastTypingReceivedAt: Date?

    mutating func receive(_ signal: TypingSignal, at receivedAt: Date) {
        lastTypingReceivedAt = signal == .typing ? receivedAt : nil
    }

    mutating func clear() {
        lastTypingReceivedAt = nil
    }

    func isTyping(at now: Date) -> Bool {
        guard let lastTypingReceivedAt else {
            return false
        }

        return now.timeIntervalSince(lastTypingReceivedAt) < HushConfig.peerTypingExpiry
    }
}
