import Foundation
import Testing
@testable import Hush

struct ChatSessionTests {
    private func message() -> ChatMessage {
        ChatMessage(identity: MessageIdentity(senderIP: "192.168.0.35", createdAt: Date(timeIntervalSince1970: 1_000),
            contentHash: PacketCodec.contentHash("안녕하세요")), content: "안녕하세요")
    }

    @Test func 상대가_오프라인이어도_메시지를_기록하고_세_번의_전송을_준비한다() throws {
        // Given: 상대 heartbeat를 받지 않은 채팅 세션이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        var session = try ChatSession(role: .chat, localIP: "192.168.0.34", ownIPs: [], store: store)
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(!session.isPeerOnline(at: now))
        // When: 메시지 송신을 준비합니다.
        let (sent, plan) = try session.prepareSend(content: "안녕하세요", at: now, contentHash: PacketCodec.contentHash("안녕하세요"))
        // Then: 오프라인으로 송신을 막지 않고 내 메시지를 한 번 기록합니다.
        #expect(plan.transmissions.count == 3)
        #expect(try store.load() == [RecordedMessage(message: sent, isOutgoing: true)])
    }

    @Test func 수신기에서_기록한_메시지를_채팅이_조회하면_한_번만_표시한다() throws {
        // Given: 같은 암호화 기록을 사용하는 수신기와 채팅 세션이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        var receiver = try ChatSession(role: .backgroundReceiver, localIP: "192.168.0.34", ownIPs: [], store: store)
        var chat = try ChatSession(role: .chat, localIP: "192.168.0.34", ownIPs: [], store: store)
        let incoming = message()
        // When: 수신기가 반복 메시지를 저장하고 채팅이 기록과 패킷을 조회합니다.
        _ = try receiver.receiveMessage(incoming)
        _ = try receiver.receiveMessage(incoming)
        let refreshed = try chat.refreshHistory()
        let repeated = try chat.receiveMessage(incoming)
        // Then: 표시할 메시지는 한 건이며 다시 수신해도 추가되지 않습니다.
        #expect(refreshed == [RecordedMessage(message: incoming, isOutgoing: false)])
        #expect(repeated == nil)
        #expect(try store.load().count == 1)
    }

    @Test func 내_heartbeat는_상대_상태를_바꾸거나_기록에_남지_않는다() throws {
        // Given: 채팅용 세션이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        var session = try ChatSession(role: .chat, localIP: "192.168.0.34", ownIPs: ["192.168.0.34"], store: store)
        let now = Date(timeIntervalSince1970: 1_000)
        // When: 내 IP의 heartbeat와 상대 IP의 heartbeat를 받습니다.
        session.receiveHeartbeat(from: "192.168.0.34", at: now)
        #expect(!session.isPeerOnline(at: now))
        session.receiveHeartbeat(from: "192.168.0.35", at: now)
        // Then: 상대의 heartbeat만 온라인 판정에 사용하며 기록은 비어 있습니다.
        #expect(session.isPeerOnline(at: now))
        #expect(!session.isPeerOnline(at: now.addingTimeInterval(12)))
        #expect(session.peerIP == "192.168.0.35")
        #expect(try store.load().isEmpty)
    }

    @Test func 내_입력_중_신호는_상대_입력_중으로_판단하지_않는다() throws {
        // Given: 채팅용 세션이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        var session = try ChatSession(role: .chat, localIP: "192.168.0.34", ownIPs: ["192.168.0.34"], store: store)
        let now = Date(timeIntervalSince1970: 1_000)
        // When: 내 IP의 입력 중 신호와 상대 IP의 입력 중 신호를 차례로 받습니다.
        session.receiveTyping(.typing, from: "192.168.0.34", at: now)
        let afterOwn = session.isPeerTyping(at: now)
        session.receiveTyping(.typing, from: "192.168.0.35", at: now)
        // Then: 상대의 신호만 입력 중 판단에 사용하며 기록은 비어 있습니다.
        #expect(!afterOwn)
        #expect(session.isPeerTyping(at: now))
        #expect(try store.load().isEmpty)
    }

    @Test func 상대의_새_메시지는_입력_중_표시를_끝내고_반복_수신본은_끝내지_않는다() throws {
        // Given: 상대가 입력 중인 채팅 세션이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        var session = try ChatSession(role: .chat, localIP: "192.168.0.34", ownIPs: ["192.168.0.34"], store: store)
        let now = Date(timeIntervalSince1970: 1_000)
        session.receiveTyping(.typing, from: "192.168.0.35", at: now)
        // When: 상대 메시지를 받고, 상대가 다음 메시지를 쓰는 중에 같은 메시지의 반복 수신본을 받습니다.
        _ = try session.receiveMessage(message())
        let afterMessage = session.isPeerTyping(at: now)
        session.receiveTyping(.typing, from: "192.168.0.35", at: now)
        _ = try session.receiveMessage(message())
        // Then: 새 메시지에서만 표시를 끝내고 반복 수신본은 다음 입력 중 표시를 지우지 않습니다.
        #expect(!afterMessage)
        #expect(session.isPeerTyping(at: now))
    }

    @Test func 수신기가_먼저_저장한_상대_메시지를_조회해도_입력_중_표시를_끝낸다() throws {
        // Given: 상대가 입력 중인 채팅과 같은 기록을 사용하는 수신기가 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(directory: directory, password: "비밀번호")
        var receiver = try ChatSession(role: .backgroundReceiver, localIP: "192.168.0.34", ownIPs: [], store: store)
        var chat = try ChatSession(role: .chat, localIP: "192.168.0.34", ownIPs: [], store: store)
        let now = Date(timeIntervalSince1970: 1_000)
        chat.receiveTyping(.typing, from: "192.168.0.35", at: now)
        // When: 수신기가 저장한 상대 메시지를 채팅이 기록 조회로 받습니다.
        _ = try receiver.receiveMessage(message())
        _ = try chat.refreshHistory()
        // Then: 입력 중 표시를 끝냅니다.
        #expect(!chat.isPeerTyping(at: now))
    }
}
