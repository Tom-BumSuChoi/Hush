import CryptoKit
import Foundation

// 내용과 IP 대신 메시지 식별자의 해시만 보관합니다. 수신함 병합과 읽음 처리는 독립적입니다.
enum UnreadStore {
    private struct State: Codable {
        var seen: Set<String> = []
        var unread: Set<String> = []
    }

    private static func token(_ identity: MessageIdentity) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: try encoder.encode(identity)).map { String(format: "%02x", $0) }.joined()
    }

    private static func update(in directory: URL, _ body: (inout State) throws -> Void) throws {
        let url = directory.appendingPathComponent("unread.json")
        try HistoryStore.withLock(at: url) {
            let data = try? Data(contentsOf: url)
            var state = try data.map { try JSONDecoder().decode(State.self, from: $0) } ?? State()
            let previous = state
            try body(&state)
            guard previous.seen != state.seen || previous.unread != state.unread else { return }
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    static func received(_ identity: MessageIdentity, in directory: URL) throws {
        let id = try token(identity)
        try update(in: directory) { state in
            if state.seen.insert(id).inserted { state.unread.insert(id) }
        }
    }

    static func markRead(_ identities: Set<MessageIdentity>, in directory: URL) throws {
        let ids = try Set(identities.map(token))
        try update(in: directory) { state in
            state.seen.formUnion(ids)
            state.unread.subtract(ids)
        }
    }

    static func count(in directory: URL) throws -> Int {
        var count = 0
        try update(in: directory) { count = $0.unread.count }
        return count
    }
}
