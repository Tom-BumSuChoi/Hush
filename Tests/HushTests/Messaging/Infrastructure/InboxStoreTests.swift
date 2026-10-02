import CryptoKit
import Foundation
import Testing
@testable import Hush

struct InboxStoreTests {
    private let password = "inbox-test-password"

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func record(_ content: String, at seconds: TimeInterval, outgoing: Bool = false) -> RecordedMessage {
        RecordedMessage(message: ChatMessage(identity: MessageIdentity(senderIP: "192.168.0.34",
            createdAt: Date(timeIntervalSince1970: seconds), contentHash: PacketCodec.contentHash(content)), content: content),
            isOutgoing: outgoing)
    }

    @Test func 수신기는_비밀번호_없이_공개키로만_쌓고_평문을_남기지_않는다() throws {
        // Given: 비밀번호로 한 번 연 기록과 같은 위치의 수신기가 있습니다.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try HistoryStore(directory: directory, password: password)
        let writer = try InboxWriter(directory: directory)
        // When: 같은 메시지를 반복 수신해 수신함에 저장합니다.
        let first = try writer.append(record("수신함 비밀 내용", at: 100))
        let repeated = try writer.append(record("수신함 비밀 내용", at: 100))
        // Then: 한 건만 쌓이며 파일에 평문이 없고 수신기는 기록을 읽지 않습니다.
        let data = try Data(contentsOf: writer.url)
        #expect(first)
        #expect(!repeated)
        #expect(data.split(separator: UInt8(ascii: "\n")).count == 1)
        #expect(!String(decoding: data, as: UTF8.self).contains("수신함 비밀 내용"))
        #expect(try writer.load().isEmpty)
    }

    @Test func 비밀번호로_기록을_열면_수신함을_중복_없이_합치고_비운다() throws {
        // Given: 기록에 이미 있는 메시지와 새 메시지가 수신함에 쌓여 있습니다.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = record("이미 받은 메시지", at: 100)
        let fresh = record("화면 종료 뒤 받은 메시지", at: 200)
        try HistoryStore(directory: directory, password: password).append(existing)
        let writer = try InboxWriter(directory: directory)
        try writer.append(existing)
        try writer.append(fresh)
        #expect(Inbox.pendingCount(in: directory) == 2)
        // When: 비밀번호로 기록을 다시 열어 조회합니다.
        let records = try HistoryStore(directory: directory, password: password).load()
        // Then: 새 메시지만 상대 메시지로 추가되고 수신함은 비워집니다.
        #expect(records == [existing, fresh])
        #expect(Inbox.pendingCount(in: directory) == 0)
        #expect(try Data(contentsOf: writer.url).isEmpty)
    }

    @Test func 수신함_개인키는_다른_비밀번호나_통신용_키로_열_수_없다() throws {
        // Given: 수신함 열쇠가 준비된 기록과 다른 비밀번호의 기록이 있습니다.
        let directory = temporaryDirectory()
        let other = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: other)
        }
        _ = try HistoryStore(directory: directory, password: password)
        _ = try HistoryStore(directory: other, password: "other-password")
        let file = try Inbox.readKeyFile(in: directory)
        let box = try AES.GCM.SealedBox(combined: file.sealedPrivateKey)
        // When: 통신용 키로 개인키를 열고, 다른 기록의 열쇠로 수신함 항목을 엽니다.
        let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: file.publicKey)
        let line = try Inbox.seal(record("다른 열쇠 시험", at: 100).message, to: publicKey)
        let otherBox = try AES.GCM.SealedBox(combined: Inbox.readKeyFile(in: other).sealedPrivateKey)
        // Then: 통신용 내장 키로는 개인키를 열 수 없고 다른 열쇠로는 항목을 열 수 없습니다.
        #expect(throws: (any Error).self) { try AES.GCM.open(box, using: HushConfig.communicationKey) }
        #expect(throws: (any Error).self) { try AES.GCM.open(otherBox, using: HushConfig.communicationKey) }
        #expect(throws: (any Error).self) { try Inbox.open(line, with: Curve25519.KeyAgreement.PrivateKey()) }
    }

    @Test func 수신함_열쇠는_다시_열어도_유지되고_없으면_수신기를_시작하지_않는다() throws {
        // Given: 비밀번호로 연 적이 없는 위치와 두 번 연 기록이 있습니다.
        let directory = temporaryDirectory()
        let empty = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try HistoryStore(directory: directory, password: password)
        let first = try Inbox.readKeyFile(in: directory).publicKey
        _ = try HistoryStore(directory: directory, password: password)
        // When: 수신함 열쇠를 다시 확인하고 열쇠 없는 위치에서 수신기를 준비합니다.
        let second = try Inbox.readKeyFile(in: directory).publicKey
        // Then: 같은 열쇠를 유지하며 열쇠가 없으면 수신기를 시작하지 않습니다.
        #expect(first == second)
        #expect(throws: Inbox.InboxError.self) { try InboxWriter(directory: empty) }
    }
}
