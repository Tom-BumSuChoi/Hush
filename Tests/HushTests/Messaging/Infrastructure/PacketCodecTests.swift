import CryptoKit
import Foundation
import Testing
@testable import Hush

struct PacketCodecTests {
    @Test func 암호화한_메시지를_복호화하면_내용과_생성_시각이_유지된다() throws {
        // Given: 같은 통신용 키와 새 메시지가 있습니다.
        let codec = PacketCodec(key: SymmetricKey(size: .bits256))
        let message = ChatMessage(identity: MessageIdentity(senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: 1_000.123456), contentHash: PacketCodec.contentHash("안녕하세요")),
            content: "안녕하세요")
        // When: 메시지를 암호화한 뒤 실제 패킷 출발 IP로 복호화합니다.
        let encrypted = try codec.encode(.message(message))
        let decoded = try codec.decode(encrypted, senderIP: message.identity.senderIP)
        // Then: 평문이 노출되지 않고 원래 메시지를 복원합니다.
        #expect(!encrypted.contains(Data(message.content.utf8)))
        #expect(decoded == .message(message))
    }

    @Test func 발신_IP는_메시지에_주장된_주소가_아닌_수신_패킷_출발_주소이다() throws {
        // Given: 발신 IP를 주장하는 메시지가 있습니다.
        let codec = PacketCodec(key: SymmetricKey(size: .bits256))
        let message = ChatMessage(identity: MessageIdentity(senderIP: "192.168.0.99",
            createdAt: Date(), contentHash: "임의의 해시"), content: "내용")
        // When: 실제 출발 IP가 다른 패킷을 수신합니다.
        let decoded = try codec.decode(codec.encode(.message(message)), senderIP: "192.168.0.35")
        // Then: 출발 IP와 실제 내용에서 계산한 해시로 식별합니다.
        guard case .message(let received) = decoded else { Issue.record("메시지 수신 필요"); return }
        #expect(received.identity.senderIP == "192.168.0.35")
        #expect(received.identity.contentHash == PacketCodec.contentHash(message.content))
    }

    @Test func 변조된_패킷과_다른_키의_패킷은_복호화되지_않는다() throws {
        // Given: 정상적으로 암호화한 패킷이 있습니다.
        let codec = PacketCodec(key: SymmetricKey(size: .bits256))
        let other = PacketCodec(key: SymmetricKey(size: .bits256))
        let encrypted = try codec.encode(.heartbeat)
        var tampered = encrypted
        tampered[tampered.count - 1] ^= 1
        // When: 변조된 패킷과 다른 키의 패킷을 복호화합니다.
        // Then: 인증에 실패하여 정상 패킷을 반환하지 않습니다.
        #expect(throws: (any Error).self) { try codec.decode(tampered, senderIP: "192.168.0.35") }
        #expect(throws: (any Error).self) { try other.decode(encrypted, senderIP: "192.168.0.35") }
    }

    @Test func heartbeat는_채팅_메시지와_구분된다() throws {
        // Given: 통신용 키가 있습니다.
        let codec = PacketCodec(key: SymmetricKey(size: .bits256))
        // When: heartbeat를 암복호화합니다.
        let decoded = try codec.decode(codec.encode(.heartbeat), senderIP: "192.168.0.35")
        // Then: 대화에 기록할 메시지가 아닌 heartbeat입니다.
        #expect(decoded == .heartbeat)
    }

    @Test func UDP_한도를_넘는_메시지는_송신_전에_거부된다() {
        // Given: UDP 한도를 넘는 메시지가 있습니다.
        let codec = PacketCodec(key: SymmetricKey(size: .bits256))
        let message = ChatMessage(identity: MessageIdentity(senderIP: "127.0.0.1", createdAt: Date(), contentHash: ""),
                                  content: String(repeating: "가", count: 30_000))
        // When: 암호화 패킷을 만듭니다.
        // Then: 패킷 크기 초과를 반환합니다.
        #expect(throws: PacketCodec.PacketError.messageTooLarge) { try codec.encode(.message(message)) }
    }
}
