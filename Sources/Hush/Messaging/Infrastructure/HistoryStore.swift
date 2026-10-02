import CommonCrypto
import CryptoKit
import Darwin
import Foundation

final class HistoryStore: ConversationStore {
    let url: URL
    private let key: SymmetricKey
    private let salt: Data
    private let inboxKey: Curve25519.KeyAgreement.PrivateKey
    private static let iterations: UInt32 = 600_000
    private static let context = Data("Hush.history.v1".utf8)
    private static let inboxKeyContext = Data("Hush.inbox-key.v1".utf8)

    init(directory: URL, password: String) throws {
        guard !password.isEmpty else { throw HistoryError.emptyPassword }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent("history.json")
        self.url = url
        let values = try Self.withLock(at: url) { () -> (SymmetricKey, Data, Curve25519.KeyAgreement.PrivateKey) in
            if FileManager.default.fileExists(atPath: url.path) {
                let archive = try Self.readArchive(at: url)
                let key = try Self.deriveKey(password: password, salt: archive.salt)
                _ = try Self.decrypt(archive, using: key)
                return (key, archive.salt, try Self.prepareInboxKey(in: directory, key: key))
            }
            let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
            let key = try Self.deriveKey(password: password, salt: salt)
            try Self.write([], key: key, salt: salt, to: url)
            return (key, salt, try Self.prepareInboxKey(in: directory, key: key))
        }
        key = values.0
        salt = values.1
        inboxKey = values.2
    }

    // 기록을 읽을 때 백그라운드 수신기가 쌓은 수신함을 먼저 합칩니다.
    func load() throws -> [RecordedMessage] {
        try Self.withLock(at: url) {
            try mergeInbox()
            return try read()
        }
    }

    @discardableResult
    func append(_ record: RecordedMessage) throws -> Bool {
        try Self.withLock(at: url) {
            var records = try read()
            guard !records.contains(where: { $0.message.identity == record.message.identity }) else { return false }
            records.append(record)
            try Self.write(records, key: key, salt: salt, to: url)
            return true
        }
    }

    private func mergeInbox() throws {
        let inbox = Inbox.url(in: url.deletingLastPathComponent())
        guard let size = try? FileManager.default.attributesOfItem(atPath: inbox.path)[.size] as? Int, size > 0 else { return }
        try Self.withLock(at: inbox) {
            var records = try read()
            var changed = false
            for line in try Data(contentsOf: inbox).split(separator: UInt8(ascii: "\n")) {
                // 다른 열쇠로 봉인되었거나 손상된 항목은 열 수 없으므로 건너뜁니다.
                guard let message = try? Inbox.open(Data(line), with: inboxKey),
                      !records.contains(where: { $0.message.identity == message.identity }) else { continue }
                records.append(RecordedMessage(message: message, isOutgoing: false))
                changed = true
            }
            if changed { try Self.write(records, key: key, salt: salt, to: url) }
            guard truncate(inbox.path, 0) == 0 else { throw SocketFailure("수신함 비우기") }
        }
    }

    // 수신함 개인키는 기록용 키로 봉인해 보관하며, 열 수 없으면 새 열쇠쌍으로 바꿉니다.
    private static func prepareInboxKey(in directory: URL, key: SymmetricKey) throws -> Curve25519.KeyAgreement.PrivateKey {
        if let file = try? Inbox.readKeyFile(in: directory),
           let box = try? AES.GCM.SealedBox(combined: file.sealedPrivateKey),
           let raw = try? AES.GCM.open(box, using: key, authenticating: inboxKeyContext),
           let privateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw),
           privateKey.publicKey.rawRepresentation == file.publicKey {
            return privateKey
        }
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        guard let sealed = try AES.GCM.seal(privateKey.rawRepresentation, using: key, authenticating: inboxKeyContext).combined else {
            throw HistoryError.invalidArchive
        }
        let file = Inbox.KeyFile(version: 1, publicKey: privateKey.publicKey.rawRepresentation, sealedPrivateKey: sealed)
        try writeFile(JSONEncoder().encode(file), to: Inbox.keyURL(in: directory))
        return privateKey
    }

    private func read() throws -> [RecordedMessage] {
        let archive = try Self.readArchive(at: url)
        guard archive.salt == salt else { throw HistoryError.invalidArchive }
        return try Self.decrypt(archive, using: key)
    }

    private static func readArchive(at url: URL) throws -> Archive {
        let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url))
        guard archive.version == 1, archive.iterations == iterations, archive.salt.count == 16 else {
            throw HistoryError.invalidArchive
        }
        return archive
    }

    private static func decrypt(_ archive: Archive, using key: SymmetricKey) throws -> [RecordedMessage] {
        let box = try AES.GCM.SealedBox(combined: archive.sealed)
        let data = try AES.GCM.open(box, using: key, authenticating: context)
        return try JSONDecoder().decode([RecordedMessage].self, from: data)
    }

    private static func write(_ records: [RecordedMessage], key: SymmetricKey, salt: Data, to url: URL) throws {
        let plaintext = try JSONEncoder().encode(records)
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: context)
        guard let sealed = box.combined else { throw HistoryError.invalidArchive }
        try writeFile(JSONEncoder().encode(Archive(version: 1, salt: salt, iterations: iterations, sealed: sealed)), to: url)
    }

    private static func writeFile(_ data: Data, to url: URL) throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".history-\(UUID().uuidString)")
        let fd = open(temporary.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
        guard fd >= 0 else { throw SocketFailure("기록 임시 파일 생성") }
        defer { close(fd); try? FileManager.default.removeItem(at: temporary) }
        var written = 0
        try data.withUnsafeBytes { bytes in
            while written < bytes.count {
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: written), bytes.count - written)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw SocketFailure("암호화 기록 쓰기") }
                written += count
            }
        }
        guard fsync(fd) == 0 else { throw SocketFailure("암호화 기록 동기화") }
        guard rename(temporary.path, url.path) == 0 else { throw SocketFailure("암호화 기록 교체") }
    }

    private static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        var output = [UInt8](repeating: 0, count: 32)
        let status = password.withCString { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes, password.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations, &output, output.count)
            }
        }
        guard status == kCCSuccess else { throw HistoryError.keyDerivationFailed }
        defer { output.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        return SymmetricKey(data: output)
    }

    static func withLock<T>(at url: URL, _ body: () throws -> T) throws -> T {
        let fd = open(url.path + ".lock", O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw SocketFailure("기록 잠금 파일 생성") }
        defer { close(fd) }
        while flock(fd, LOCK_EX) != 0 {
            guard errno == EINTR else { throw SocketFailure("기록 파일 잠금") }
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    enum HistoryError: Error {
        case emptyPassword
        case invalidArchive
        case keyDerivationFailed
    }

    private struct Archive: Codable {
        let version: Int
        let salt: Data
        let iterations: UInt32
        let sealed: Data
    }
}
