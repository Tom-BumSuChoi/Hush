import AppKit

enum TerminalLauncher {
    // 다른 앱을 제어하는 권한 없이 기본 터미널에서 hush를 열도록 실행 스크립트 파일을 만들어 엽니다.
    static func openHush(executable: URL, directory: URL) throws {
        let script = directory.appendingPathComponent("Hush.command")
        let quoted = "'" + executable.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        try Data("#!/bin/sh\nexec \(quoted)\n".utf8).write(to: script, options: .atomic)
        guard chmod(script.path, 0o700) == 0 else { throw SocketFailure("Hush 실행 스크립트 권한 설정") }
        NSWorkspace.shared.open(script)
    }
}
