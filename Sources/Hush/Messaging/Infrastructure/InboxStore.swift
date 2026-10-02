import CryptoKit
import Darwin
import Foundation

// 비밀번호 없이 실행하는 수신기는 공개키로만 봉인해 수신함에 쌓으며, 수신함과 기록을 읽을 수 없습니다.
final class InboxWriter: ConversationStore {
    let url: URL
    private let publicKey: Curve25519.KeyAgreement.PublicKey
    // 기록을 읽을 수 없으므로 중복은 실행 중 메모리에서만 거르고, 남은 중복은 기록에 합칠 때 거릅니다.
    private var written: Set<MessageIdentity> = []

    init(directory: URL) throws {
        guard let file = try? Inbox.readKeyFile(in: directory),
              let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: file.publicKey) else {
            throw Inbox.InboxError.missingKey
        }
        self.publicKey = publicKey
        url = Inbox.url(in: directory)
    }

    func load() throws -> [RecordedMessage] { [] }

    @discardableResult
    func append(_ record: RecordedMessage) throws -> Bool {
        guard !written.contains(record.message.identity) else { return false }
        let line = try Inbox.seal(record.message, to: publicKey) + Data("\n".utf8)
        try HistoryStore.withLock(at: url) {
            let fd = open(url.path, O_CREAT | O_WRONLY | O_APPEND, 0o600)
            guard fd >= 0 else { throw SocketFailure("수신함 열기") }
            defer { close(fd) }
            try line.withUnsafeBytes { bytes in
                var written = 0
                while written < bytes.count {
                    let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: written), bytes.count - written)
                    if count < 0, errno == EINTR { continue }
                    guard count > 0 else { throw SocketFailure("수신함 쓰기") }
                    written += count
                }
            }
            guard fsync(fd) == 0 else { throw SocketFailure("수신함 동기화") }
        }
        written.insert(record.message.identity)
        return true
    }
}

enum Inbox {
    struct KeyFile: Codable {
        let version: Int
        let publicKey: Data
        let sealedPrivateKey: Data
    }

    private struct Entry: Codable {
        let version: Int
        let ephemeralPublicKey: Data
        let sealed: Data
    }

    enum InboxError: Error, CustomStringConvertible {
        case missingKey
        case invalidEntry

        var description: String {
            switch self {
            case .missingKey: "수신함 열쇠가 없습니다. hush를 먼저 실행해 비밀번호를 설정하세요"
            case .invalidEntry: "수신함 항목을 읽을 수 없습니다"
            }
        }
    }

    private static let context = Data("Hush.inbox.v1".utf8)

    static func url(in directory: URL) -> URL { directory.appendingPathComponent("inbox.jsonl") }
    static func keyURL(in directory: URL) -> URL { directory.appendingPathComponent("inbox-key.json") }

    static func readKeyFile(in directory: URL) throws -> KeyFile {
        let file = try JSONDecoder().decode(KeyFile.self, from: Data(contentsOf: keyURL(in: directory)))
        guard file.version == 1 else { throw InboxError.missingKey }
        return file
    }

    // 메시지마다 일회용 키와 수신함 공개키의 키 합의로 만든 키로 암호화합니다.
    static func seal(_ message: ChatMessage, to recipient: Curve25519.KeyAgreement.PublicKey) throws -> Data {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let key = messageKey(try ephemeral.sharedSecretFromKeyAgreement(with: recipient),
            ephemeral: ephemeral.publicKey, recipient: recipient)
        guard let sealed = try AES.GCM.seal(JSONEncoder().encode(message), using: key, authenticating: context).combined else {
            throw InboxError.invalidEntry
        }
        return try JSONEncoder().encode(Entry(version: 1, ephemeralPublicKey: ephemeral.publicKey.rawRepresentation, sealed: sealed))
    }

    static func open(_ line: Data, with privateKey: Curve25519.KeyAgreement.PrivateKey) throws -> ChatMessage {
        let entry = try JSONDecoder().decode(Entry.self, from: line)
        guard entry.version == 1 else { throw InboxError.invalidEntry }
        let ephemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: entry.ephemeralPublicKey)
        let key = messageKey(try privateKey.sharedSecretFromKeyAgreement(with: ephemeral),
            ephemeral: ephemeral, recipient: privateKey.publicKey)
        let data = try AES.GCM.open(AES.GCM.SealedBox(combined: entry.sealed), using: key, authenticating: context)
        return try JSONDecoder().decode(ChatMessage.self, from: data)
    }

    private static func messageKey(_ secret: SharedSecret, ephemeral: Curve25519.KeyAgreement.PublicKey,
                                   recipient: Curve25519.KeyAgreement.PublicKey) -> SymmetricKey {
        secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: ephemeral.rawRepresentation + recipient.rawRepresentation,
            sharedInfo: context, outputByteCount: 32)
    }
}
