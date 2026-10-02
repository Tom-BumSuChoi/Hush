import Foundation
import Testing
@testable import Hush

struct ReceiverAgentTests {
    @Test func 로그인부터_계속_실행하는_수신기_등록_파일을_만든다() throws {
        // Given: 설치한 실행 파일과 로그 위치가 있습니다.
        let executable = URL(fileURLWithPath: "/Users/tester/.local/bin/hush")
        let log = URL(fileURLWithPath: "/Users/tester/Library/Logs/Hush/receiver.log")
        // When: LaunchAgent 등록 파일을 만듭니다.
        let data = try ReceiverAgent.plist(executable: executable, logURL: log)
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        // Then: 로그인 시 메뉴 막대를 켠 비밀번호 없는 수신 역할로 실행하고 종료되면 다시 실행합니다.
        #expect(plist["Label"] as? String == "local.hush.receiver")
        #expect(plist["ProgramArguments"] as? [String] == ["/Users/tester/.local/bin/hush", "receive", "--menu-bar"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["KeepAlive"] as? Bool == true)
        #expect(plist["StandardOutPath"] as? String == log.path)
        #expect(plist["StandardErrorPath"] as? String == log.path)
    }
}
