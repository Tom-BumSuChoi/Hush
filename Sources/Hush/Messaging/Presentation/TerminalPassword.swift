import CryptoKit
import Darwin
import Foundation

enum TerminalPassword {
    static func unlockHistory(at directory: URL) throws -> HistoryStore {
        let exists = FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json").path)
        let password = try read(exists ? "개인 비밀번호: " : "새 개인 비밀번호: ")
        if !exists {
            let confirmation = try read("비밀번호 확인: ")
            guard password == confirmation else { throw CLIError("비밀번호 확인이 일치하지 않습니다") }
        }
        do {
            return try HistoryStore(directory: directory, password: password)
        } catch is CryptoKitError {
            throw CLIError("비밀번호가 올바르지 않거나 기록이 손상되었습니다")
        }
    }

    private static func read(_ prompt: String) throws -> String {
        guard isatty(STDIN_FILENO) == 1 else { throw CLIError("비밀번호 입력을 위해 터미널에서 직접 실행하세요") }
        guard let pointer = getpass(TerminalChatView.styled(prompt)) else { throw CLIError("비밀번호를 읽을 수 없습니다") }
        let count = strlen(pointer)
        defer { _ = memset_s(pointer, count, 0, count) }
        let password = String(cString: pointer)
        guard !password.isEmpty else { throw CLIError("빈 비밀번호는 사용할 수 없습니다") }
        return password
    }
}
