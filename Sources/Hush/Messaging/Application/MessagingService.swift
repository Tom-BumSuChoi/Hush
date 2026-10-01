import Foundation

struct MessagingService {
    private var conversation: Conversation

    init(messages: [ChatMessage] = []) {
        conversation = Conversation(messages: messages)
    }

    var messages: [ChatMessage] {
        conversation.messages
    }

    mutating func prepareSend(_ message: ChatMessage, at startedAt: Date) -> MessageTransmissionPlan? {
        guard conversation.record(message) else {
            return nil
        }

        return MessageTransmissionPlan(identity: message.identity, startedAt: startedAt)
    }

    mutating func receive(_ message: ChatMessage) -> ChatMessage? {
        guard conversation.record(message) else {
            return nil
        }

        return message
    }
}
