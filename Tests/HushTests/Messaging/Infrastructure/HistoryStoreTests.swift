import CryptoKit
import Foundation
import Testing
@testable import Hush

struct HistoryStoreTests {
    private func record(_ content: String = "비밀 대화", outgoing: Bool = false, time: Double = 1_000) -> RecordedMessage {
        RecordedMessage(message: ChatMessage(identity: MessageIdentity(senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: time), contentHash: PacketCodec.contentHash(content)), content: content),
            isOutgoing: outgoing)
    }

    @Test func 기록은_평문을_남기지_않고_같은_비밀번호로_재시작하면_복원된다() throws {
        // Given: 개인 비밀번호로 새 기록을 열었습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "개인 비밀번호")
        let saved = record(outgoing: true)
        // When: 기록하고 같은 비밀번호로 다시 엽니다.
        try store.append(saved)
        let bytes = try Data(contentsOf: store.url)
        let restored = try HistoryStore(directory: directory, password: "개인 비밀번호")
        // Then: 파일에 평문이 없고 내 메시지 여부까지 복원됩니다.
        #expect(bytes.range(of: Data(saved.message.content.utf8)) == nil)
        #expect(try restored.load() == [saved])
        let permissions = try FileManager.default.attributesOfItem(atPath: store.url.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func 잘못된_비밀번호로_기록을_열면_실패하고_기존_기록은_유지된다() throws {
        // Given: 비밀번호로 보호한 기존 기록이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "올바른 비밀번호")
        try store.append(record())
        let before = try Data(contentsOf: store.url)
        // When: 다른 비밀번호로 기록을 엽니다.
        // Then: 복호화가 실패하고 파일을 덮어쓰지 않습니다.
        #expect(throws: (any Error).self) { try HistoryStore(directory: directory, password: "다른 비밀번호") }
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test func 서로_다른_프로세스의_저장_객체로_기록해도_중복과_덮어쓰기가_없다() throws {
        // Given: 같은 기록을 연 두 저장 객체가 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try HistoryStore(directory: directory, password: "비밀번호")
        let second = try HistoryStore(directory: directory, password: "비밀번호")
        let one = record()
        let two = record("새 대화", time: 1_001)
        // When: 첫 기록과 반복 수신본, 다른 새 기록을 저장합니다.
        let inserted = try first.append(one)
        let duplicate = try second.append(one)
        try second.append(two)
        // Then: 기존 기록과 새 기록 모두 유지되며 중복은 추가하지 않습니다.
        #expect(inserted)
        #expect(!duplicate)
        #expect(try first.load() == [one, two])
    }

    @Test func 통신용_키로는_개인_기록을_복호화할_수_없다() throws {
        // Given: 개인 비밀번호로 보호한 기록과 통신용 키가 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        let archive = try JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as! [String: Any]
        let sealed = try #require(Data(base64Encoded: archive["sealed"] as! String))
        let box = try AES.GCM.SealedBox(combined: sealed)
        // When: 통신용 키로 개인 기록을 복호화합니다.
        // Then: 개인 기록용 키와 분리되어 복호화할 수 없습니다.
        #expect(throws: (any Error).self) {
            try AES.GCM.open(box, using: SymmetricKey(size: .bits256), authenticating: Data("Hush.history.v1".utf8))
        }
    }
}
