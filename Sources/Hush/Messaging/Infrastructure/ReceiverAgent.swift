import Darwin
import Foundation

// 로그인부터 로그아웃·종료까지 비밀번호 없는 수신기를 실행하는 사용자 LaunchAgent입니다.
enum ReceiverAgent {
    static let label = "local.hush.receiver"

    struct AgentError: Error, CustomStringConvertible {
        let description: String
    }

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Hush/receiver.log")
    }

    private static var service: String { "gui/\(getuid())/\(label)" }

    static func plist(executable: URL, logURL: URL = logURL) throws -> Data {
        let contents: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable.path, "receive"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
        ]
        return try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0)
    }

    // 같은 실행 파일로 이미 등록되어 있으면 그대로 두고, 아니면 등록 파일을 바꿔 다시 등록합니다.
    static func ensureRegistered(executable: URL) throws {
        let data = try plist(executable: executable)
        let loaded = try launchctl(["print", service]).status == 0
        if loaded, (try? Data(contentsOf: plistURL)) == data { return }
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
        if loaded { _ = try launchctl(["bootout", service]) }
        // 직전 등록 해제가 끝나기 전에는 등록이 실패할 수 있어 잠시 다시 시도합니다.
        var result = try launchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        for _ in 0..<20 where result.status != 0 {
            usleep(100_000)
            result = try launchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        }
        guard result.status == 0 else { throw AgentError(description: "수신기 등록 실패: \(result.output)") }
    }

    static func isRunning() -> Bool {
        guard let result = try? launchctl(["print", service]), result.status == 0 else { return false }
        return result.output.contains("state = running")
    }

    private static func launchctl(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
