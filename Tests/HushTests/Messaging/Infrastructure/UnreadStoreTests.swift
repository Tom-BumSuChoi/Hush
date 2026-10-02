import Foundation
import Testing
@testable import Hush

struct UnreadStoreTests {
    @Test func mergingInboxDoesNotAcknowledgeMessages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = try HistoryStore(directory: directory, password: "test")
        let receiver = try InboxWriter(directory: directory)
        let identity = MessageIdentity(senderIP: "192.168.0.2", createdAt: Date(), contentHash: "message")
        try receiver.append(RecordedMessage(message: ChatMessage(identity: identity, content: "hello"), isOutgoing: false))
        #expect(try history.load().count == 1)
        #expect(Inbox.pendingCount(in: directory) == 0)
        #expect(try UnreadStore.count(in: directory) == 1)
        try UnreadStore.markRead([identity], in: directory)
        #expect(try UnreadStore.count(in: directory) == 0)
    }

    @Test func persistsUnreadAndDeduplicatesLateReceiverWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = MessageIdentity(senderIP: "192.168.0.2", createdAt: Date(), contentHash: "first")
        let second = MessageIdentity(senderIP: "192.168.0.2", createdAt: Date(), contentHash: "second")
        try UnreadStore.received(first, in: directory)
        try UnreadStore.received(first, in: directory)
        try UnreadStore.received(second, in: directory)
        #expect(try UnreadStore.count(in: directory) == 2)
        try UnreadStore.markRead([first], in: directory)
        try UnreadStore.received(first, in: directory)
        #expect(try UnreadStore.count(in: directory) == 1)
        try UnreadStore.markRead([second], in: directory)
        #expect(try UnreadStore.count(in: directory) == 0)
    }
}
