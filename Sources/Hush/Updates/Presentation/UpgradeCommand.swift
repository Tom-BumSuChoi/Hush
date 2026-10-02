import Foundation

enum UpgradeCommand {
    static func run() throws {
        guard let updater = try UpdateRuntime.configured() else { throw CLIError("업데이트 배포 주소가 설정되지 않았습니다") }
        print(TerminalChatView.styled("새 버전 확인 중 (현재 \(HushConfig.version))"))
        let installed: String?
        do { installed = try updater.upgradeNow() }
        catch { throw CLIError("업데이트 실패: \(error)") }
        if let installed {
            print(TerminalChatView.styled("\(installed) 설치 완료. 실행 중인 Hush는 새 버전으로 재시작합니다"))
        } else {
            print(TerminalChatView.styled("최신 버전입니다"))
        }
    }
}
