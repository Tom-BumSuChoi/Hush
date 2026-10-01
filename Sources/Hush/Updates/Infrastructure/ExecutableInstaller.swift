import Darwin
import Foundation

struct InstalledExecutable {
    let url: URL
    let backupURL: URL?

    func rollback() throws {
        guard let backupURL else { return }
        guard rename(backupURL.path, url.path) == 0 else { throw SocketFailure("업데이트 되돌리기") }
    }
}

struct ExecutableInstaller {
    let destination: URL

    func install(_ release: DownloadedRelease) throws -> InstalledExecutable {
        try ReleaseManifest.verifyBinary(release.binary, descriptor: release.descriptor)
        guard release.binary.count >= 4,
              [[0xCF, 0xFA, 0xED, 0xFE], [0xFE, 0xED, 0xFA, 0xCF],
               [0xCA, 0xFE, 0xBA, 0xBE], [0xBE, 0xBA, 0xFE, 0xCA],
               [0xCA, 0xFE, 0xBA, 0xBF], [0xBF, 0xBA, 0xFE, 0xCA]].contains(Array(release.binary.prefix(4)).map(Int.init)) else {
            throw InstallError.invalidExecutable
        }
        let lock = open(destination.path + ".update.lock", O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw SocketFailure("업데이트 잠금 생성") }
        defer { close(lock) }
        guard fcntl(lock, F_SETFD, FD_CLOEXEC) == 0 else { throw SocketFailure("업데이트 잠금 설정") }
        while flock(lock, LOCK_EX) != 0 {
            guard errno == EINTR else { throw SocketFailure("업데이트 잠금") }
        }
        let targetVersion = try ReleaseVersion(release.descriptor.version)
        if try ReleaseVersion(version(at: destination)) >= targetVersion {
            return InstalledExecutable(url: destination, backupURL: nil)
        }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".Hush-update-\(UUID().uuidString)")
        let backupTemporary = destination.deletingLastPathComponent().appendingPathComponent(".Hush-backup-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporary)
            try? FileManager.default.removeItem(at: backupTemporary)
        }
        try release.binary.write(to: temporary, options: .withoutOverwriting)
        guard chmod(temporary.path, 0o755) == 0 else { throw SocketFailure("업데이트 실행 권한 설정") }
        guard try version(at: temporary) == release.descriptor.version else { throw InstallError.versionMismatch }
        let backup = URL(fileURLWithPath: destination.path + ".previous")
        guard link(destination.path, backupTemporary.path) == 0 else { throw SocketFailure("기존 실행 파일 보관") }
        guard rename(backupTemporary.path, backup.path) == 0 else { throw SocketFailure("기존 실행 파일 백업 교체") }
        guard rename(temporary.path, destination.path) == 0 else { throw SocketFailure("업데이트 실행 파일 교체") }
        return InstalledExecutable(url: destination, backupURL: backup)
    }

    static func version(at url: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        let ended = DispatchSemaphore(value: 0)
        process.executableURL = url
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in ended.signal() }
        try process.run()
        if ended.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            if ended.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL); process.waitUntilExit() }
            throw InstallError.validationTimeout
        }
        guard process.terminationStatus == 0 else { throw InstallError.invalidExecutable }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try ReleaseVersion(text)
        return text
    }

    private func version(at url: URL) throws -> String { try Self.version(at: url) }

    enum InstallError: Error {
        case invalidExecutable
        case versionMismatch
        case validationTimeout
    }
}
