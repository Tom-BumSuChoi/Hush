import Foundation
import Testing
@testable import Hush

struct MainMenuTests {
    @Test func 번호_키_하나로_메뉴를_고른다() {
        // Given: 메뉴에서 누를 수 있는 키들이 있습니다.
        // When: 각 키를 해석합니다.
        // Then: 번호는 기능으로, q와 Ctrl-D는 종료로 바꾸고 나머지 키는 무시합니다.
        #expect(MainMenu.choice(for: UInt8(ascii: "1")) == .chat)
        #expect(MainMenu.choice(for: UInt8(ascii: "2")) == .history)
        #expect(MainMenu.choice(for: UInt8(ascii: "3")) == .receive)
        #expect(MainMenu.choice(for: UInt8(ascii: "q")) == .quit)
        #expect(MainMenu.choice(for: UInt8(ascii: "Q")) == .quit)
        #expect(MainMenu.choice(for: 4) == .quit)
        #expect(MainMenu.choice(for: UInt8(ascii: "4")) == nil)
        #expect(MainMenu.choice(for: 27) == nil)
    }

    @Test func 선택한_WiFi_네트워크와_메뉴를_초록으로_표시한다() {
        // Given: Wi-Fi 네트워크가 선택되었습니다.
        var output = ""
        let menu = MainMenu { output += $0 }
        // When: 메뉴를 표시합니다.
        menu.show(network: NetworkInterface(name: "en1", ip: "192.168.0.35", broadcastIP: "192.168.0.255"), isWiFi: true)
        // Then: 버전과 네트워크, 선택 항목이 초록으로 표시됩니다.
        #expect(output.contains("\u{1B}[32mHush \(HushConfig.version) · en1 (Wi-Fi) 192.168.0.35\u{1B}[0m"))
        #expect(output.contains("1 채팅   2 기록 보기   3 수신기 실행   q 종료"))
        #expect(output.hasSuffix("\u{1B}[32m선택: \u{1B}[0m"))
    }

    @Test func 네트워크가_없어도_메뉴를_표시한다() {
        // Given: 사용할 네트워크를 정하지 못했습니다.
        var output = ""
        let menu = MainMenu { output += $0 }
        // When: 메뉴를 표시합니다.
        menu.show(network: nil, isWiFi: false)
        // Then: 네트워크가 없다고 알리고 기록 보기 등 메뉴는 유지합니다.
        #expect(output.contains("Hush \(HushConfig.version) · 네트워크 없음"))
        #expect(output.contains("2 기록 보기"))
    }
}
