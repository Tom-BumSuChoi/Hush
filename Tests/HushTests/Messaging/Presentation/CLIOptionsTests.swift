import Foundation
import Testing
@testable import Hush

struct CLIOptionsTests {
    @Test func 옵션_없이_실행하면_기본_채팅_역할이다() throws {
        // Given: 명령행 옵션이 없습니다.
        // When: 실행 옵션을 해석합니다.
        let options = try CLIOptions(arguments: [])
        // Then: 채팅 역할과 기본 포트를 사용합니다.
        #expect(options.command == .chat)
        #expect(options.port == HushConfig.udpPort)
    }

    @Test func 수신_역할과_네트워크와_기록_위치를_명시할_수_있다() throws {
        // Given: 수신 역할과 사용할 네트워크를 지정했습니다.
        // When: 명령행을 해석합니다.
        let options = try CLIOptions(arguments: ["receive", "--interface", "en1", "--port", "49001", "--history-directory", "/private/tmp/hush-test"])
        // Then: 지정한 역할과 옵션을 사용합니다.
        #expect(options.command == .receive)
        #expect(options.interfaceName == "en1")
        #expect(options.port == 49_001)
        #expect(options.historyDirectory.path == "/private/tmp/hush-test")
    }

    @Test func 잘못된_옵션과_포트와_비밀번호_인자는_거부한다() {
        // Given: 잘못된 명령행 입력들이 있습니다.
        let inputs = [["unknown"], ["--interface"], ["--port", "0"], ["--port", "65536"], ["--password", "secret"]]
        // When: 각 입력을 해석합니다.
        // Then: 비밀번호가 명령행에 남거나 잘못된 네트워크 설정으로 실행되지 않습니다.
        for input in inputs {
            #expect(throws: CLIError.self) { try CLIOptions(arguments: input) }
        }
    }

    @Test func 네트워크가_여러_개면_지정한_인터페이스만_선택한다() throws {
        // Given: 서로 다른 두 네트워크가 있습니다.
        let interfaces = [NetworkInterface(name: "en0", ip: "192.168.0.34", broadcastIP: "192.168.0.255"),
                          NetworkInterface(name: "en1", ip: "10.0.0.34", broadcastIP: "10.0.0.255")]
        // When: 명시한 인터페이스와 지정하지 않은 경우를 확인합니다.
        let explicit = try CLIOptions(arguments: ["--interface", "en1"])
        let automatic = try CLIOptions(arguments: [])
        // Then: 지정한 네트워크를 선택하며 모호한 경우 임의로 송신하지 않습니다.
        #expect(try explicit.networkInterface(from: interfaces) == interfaces[1])
        #expect(throws: CLIError.self) { try automatic.networkInterface(from: interfaces) }
    }
}
