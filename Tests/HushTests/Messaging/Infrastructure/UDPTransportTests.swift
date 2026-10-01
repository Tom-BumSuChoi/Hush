import Darwin
import Foundation
import Testing
@testable import Hush

struct UDPTransportTests {
    @Test func 실제_UDP로_보낸_패킷과_출발_IP를_수신한다() throws {
        // Given: 로컬의 서로 다른 임시 포트에 UDP 소켓이 있습니다.
        let receiver = try UDPTransport(port: 0, bindIP: "127.0.0.1")
        let sender = try UDPTransport(port: 0, bindIP: "127.0.0.1")
        let data = Data("암호화 패킷 자리".utf8)
        // When: 실제 UDP로 패킷을 보내고 최대 1초 동안 수신을 기다립니다.
        try sender.send(data, to: "127.0.0.1", port: receiver.localPort)
        var event = pollfd(fd: receiver.descriptor, events: Int16(POLLIN), revents: 0)
        #expect(poll(&event, 1, 1_000) == 1)
        let received = try #require(try receiver.receive())
        // Then: 보낸 데이터와 소켓에서 확인한 발신 IP를 받습니다.
        #expect(received.data == data)
        #expect(received.senderIP == "127.0.0.1")
    }

    @Test func 수신할_패킷이_없으면_대기하지_않고_반환한다() throws {
        // Given: 패킷이 없는 로컬 UDP 소켓이 있습니다.
        let receiver = try UDPTransport(port: 0, bindIP: "127.0.0.1")
        // When: 수신을 시도합니다.
        let received = try receiver.receive()
        // Then: 없는 패킷을 기다리지 않습니다.
        #expect(received == nil)
    }
}
