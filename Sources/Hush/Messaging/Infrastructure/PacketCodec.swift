import CryptoKit
import Foundation

enum NetworkPacket: Equatable {
    case message(ChatMessage)
    case heartbeat
}

struct PacketCodec {
    private let key: SymmetricKey
    private let context = Data("Hush.packet.v1".utf8)

    init(key: SymmetricKey) {
        self.key = key
    }

    static func contentHash(_ content: String) -> String {
        SHA256.hash(data: Data(content.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func encode(_ packet: NetworkPacket) throws -> Data {
        let payload: Payload
        switch packet {
        case .message(let message):
            payload = Payload(version: 1, kind: .message, createdAt: message.identity.createdAt, content: message.content)
        case .heartbeat:
            payload = Payload(version: 1, kind: .heartbeat, createdAt: nil, content: nil)
        }
        let data = try JSONEncoder().encode(payload)
        let box = try AES.GCM.seal(data, using: key, authenticating: context)
        guard let combined = box.combined, combined.count <= 65_507 else {
            throw PacketError.messageTooLarge
        }
        return combined
    }

    func decode(_ data: Data, senderIP: String) throws -> NetworkPacket {
        let box = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(box, using: key, authenticating: context)
        let payload = try JSONDecoder().decode(Payload.self, from: plaintext)
        guard payload.version == 1 else { throw PacketError.unsupportedVersion }
        switch payload.kind {
        case .message:
            guard let content = payload.content, let createdAt = payload.createdAt,
                  createdAt.timeIntervalSince1970.isFinite else { throw PacketError.invalidPayload }
            return .message(ChatMessage(
                identity: MessageIdentity(senderIP: senderIP, createdAt: createdAt, contentHash: Self.contentHash(content)),
                content: content
            ))
        case .heartbeat:
            guard payload.content == nil, payload.createdAt == nil else { throw PacketError.invalidPayload }
            return .heartbeat
        }
    }

    enum PacketError: Error {
        case messageTooLarge
        case unsupportedVersion
        case invalidPayload
    }

    private struct Payload: Codable {
        enum Kind: String, Codable { case message, heartbeat }
        let version: Int
        let kind: Kind
        let createdAt: Date?
        let content: String?
    }
}
