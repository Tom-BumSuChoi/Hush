import Foundation
import Testing
@testable import Hush

struct CLIOptionsTests {
    @Test func 옵션_없이_실행하면_메뉴로_시작한다() throws {
        // Given: 명령행 옵션이 없습니다.
        // When: 실행 옵션을 해석합니다.
        let options = try CLIOptions(arguments: [])
        // Then: 메뉴와 기본 포트를 사용합니다.
        #expect(options.command == .menu)
        #expect(options.port == HushConfig.udpPort)
    }

    @Test func update와_upgrade는_같은_업데이트_명령이다() throws {
        // Given: 사용자가 update 또는 upgrade를 입력했습니다.
        // When: 명령행을 해석합니다.
        let update = try CLIOptions(arguments: ["update"])
        let upgrade = try CLIOptions(arguments: ["upgrade"])
        // Then: 둘 다 새 버전 확인 후 설치하는 명령입니다.
        #expect(update.command == .upgrade)
        #expect(upgrade.command == .upgrade)
    }

    @Test func 도움말에는_메뉴와_업데이트_명령만_안내한다() {
        // Given: 사용자에게 보이는 도움말이 있습니다.
        let help = CLIOptions.help
        // When: 안내하는 명령을 확인합니다.
        // Then: hush, hush update, hush upgrade만 보이고 테스트·검증용 옵션은 보이지 않습니다.
        #expect(help.contains("hush update"))
        #expect(help.contains("hush upgrade"))
        for hidden in ["chat", "receive", "--interface", "--port", "--history-directory", "--version", "--help"] {
            #expect(!help.contains(hidden))
        }
    }

    @Test func 채팅_역할을_명시할_수_있다() throws {
        // Given: 채팅 역할을 명령으로 지정했습니다.
        // When: 명령행을 해석합니다.
        let options = try CLIOptions(arguments: ["chat"])
        // Then: 메뉴 없이 채팅 역할로 실행합니다.
        #expect(options.command == .chat)
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

    private let ethernet = NetworkInterface(name: "en0", ip: "192.168.0.34", broadcastIP: "192.168.0.255")
    private let wifi = NetworkInterface(name: "en1", ip: "192.168.0.35", broadcastIP: "192.168.0.255")

    @Test func 지정한_인터페이스를_자동_선택보다_우선한다() throws {
        // Given: Wi-Fi와 유선 네트워크가 있고 유선을 명시했습니다.
        let preference = NetworkPreference(wifiNames: ["en1"], primaryName: "en1")
        // When: 네트워크를 선택합니다.
        let options = try CLIOptions(arguments: ["--interface", "en0"])
        // Then: 명시한 유선 네트워크를 사용합니다.
        #expect(try options.networkInterface(from: [wifi, ethernet], preference: preference) == ethernet)
    }

    @Test func 네트워크가_여러_개면_연결된_WiFi를_선택한다() throws {
        // Given: 기본 경로는 유선이지만 Wi-Fi도 같은 망에 연결되어 있습니다.
        let preference = NetworkPreference(wifiNames: ["en1"], primaryName: "en0")
        // When: 지정 없이 네트워크를 선택합니다.
        let selected = try CLIOptions(arguments: []).networkInterface(from: [ethernet, wifi], preference: preference)
        // Then: Wi-Fi를 사용합니다.
        #expect(selected == wifi)
    }

    @Test func WiFi가_없으면_기본_경로_네트워크를_선택한다() throws {
        // Given: Wi-Fi가 연결되지 않았고 두 유선 네트워크 중 하나가 기본 경로입니다.
        let other = NetworkInterface(name: "en5", ip: "10.0.0.34", broadcastIP: "10.0.0.255")
        let preference = NetworkPreference(wifiNames: ["en1"], primaryName: "en5")
        // When: 지정 없이 네트워크를 선택합니다.
        let selected = try CLIOptions(arguments: []).networkInterface(from: [ethernet, other], preference: preference)
        // Then: 기본 경로 네트워크를 사용합니다.
        #expect(selected == other)
    }

    @Test func 네트워크가_하나면_종류와_관계없이_선택한다() throws {
        // Given: 유선 네트워크 하나만 연결되어 있고 기본 경로 정보가 없습니다.
        let preference = NetworkPreference(wifiNames: [], primaryName: nil)
        // When: 지정 없이 네트워크를 선택합니다.
        let selected = try CLIOptions(arguments: []).networkInterface(from: [ethernet], preference: preference)
        // Then: 연결된 유일한 네트워크를 사용합니다.
        #expect(selected == ethernet)
    }

    @Test func 자동으로_정할_수_없으면_임의로_송신하지_않는다() throws {
        // Given: Wi-Fi도 기본 경로도 아닌 네트워크 두 개가 있습니다.
        let preference = NetworkPreference(wifiNames: [], primaryName: "utun0")
        let options = try CLIOptions(arguments: [])
        // When: 지정 없이 네트워크를 선택합니다.
        // Then: 선택을 요구합니다.
        #expect(throws: CLIError.self) { try options.networkInterface(from: [ethernet, wifi], preference: preference) }
        #expect(throws: CLIError.self) { try options.networkInterface(from: [], preference: preference) }
    }
}
