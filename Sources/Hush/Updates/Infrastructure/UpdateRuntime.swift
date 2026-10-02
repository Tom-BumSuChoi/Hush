import Darwin
import Foundation

final class UpdateRuntime: @unchecked Sendable {
    private let checker: UpdateChecker
    private let destination: URL
    // 다운로드 결과와 실행 여부만 작업 스레드와 공유하며 이 잠금으로 보호합니다.
    private let lock = NSLock()
    private var completed: Result<DownloadedRelease?, any Error>?
    private var running = false
    // 일정과 파일 식별값은 CLI 이벤트 루프에서만 조회·변경합니다.
    private var schedule = UpdateSchedule()
    private var fileIdentity: FileIdentity?

    init(checker: UpdateChecker, destination: URL) {
        self.checker = checker
        self.destination = destination
    }

    static func configured() throws -> UpdateRuntime? {
        guard HushConfig.updateManifestURL != nil || HushConfig.updateSigningPublicKeyBase64 != nil else { return nil }
        guard let url = HushConfig.updateManifestURL,
              let encoded = HushConfig.updateSigningPublicKeyBase64,
              let publicKey = Data(base64Encoded: encoded), publicKey.count == 32,
              let executable = Bundle.main.executableURL else {
            throw CLIError("업데이트 배포 URL과 올바른 서명 공개키를 함께 설정하세요")
        }
        let checker = UpdateChecker(currentVersion: try ReleaseVersion(HushConfig.version),
            source: HTTPUpdateSource(manifestURL: url, publicKey: publicKey))
        return UpdateRuntime(checker: checker, destination: executable.resolvingSymlinksInPath())
    }

    func poll(at uptime: TimeInterval) throws -> InstalledExecutable? {
        let currentIdentity = try identity()
        if fileIdentity != currentIdentity {
            fileIdentity = currentIdentity
            if try ReleaseVersion(ExecutableInstaller.version(at: destination)) > checker.currentVersion {
                return InstalledExecutable(url: destination, backupURL: nil)
            }
        }
        let outcome = lock.withLock { () -> Result<DownloadedRelease?, any Error>? in
            defer { completed = nil }
            return completed
        }
        if let outcome, let release = try outcome.get() {
            return try ExecutableInstaller(destination: destination).install(release)
        }
        if schedule.shouldCheck(at: uptime) {
            let start = lock.withLock {
                guard !running else { return false }
                running = true
                return true
            }
            if start {
                schedule.recordCheck(at: uptime)
                Task.detached { [self] in
                    let result: Result<DownloadedRelease?, any Error>
                    do { result = .success(try await checker.check()) }
                    catch { result = .failure(error) }
                    lock.withLock { completed = result; running = false }
                }
            }
        }
        return nil
    }

    // 수동 업데이트는 확인부터 설치까지 기다린 뒤 설치한 버전을 반환하며, 이미 최신이면 nil을 반환합니다.
    func upgradeNow() throws -> String? {
        let finished = DispatchSemaphore(value: 0)
        Task.detached { [self] in
            let result: Result<DownloadedRelease?, any Error>
            do { result = .success(try await checker.check()) }
            catch { result = .failure(error) }
            lock.withLock { completed = result }
            finished.signal()
        }
        finished.wait()
        let outcome = lock.withLock { () -> Result<DownloadedRelease?, any Error>? in
            defer { completed = nil }
            return completed
        }
        guard let release = try outcome?.get() else { return nil }
        let installed = try ExecutableInstaller(destination: destination).install(release)
        return installed.backupURL == nil ? nil : release.descriptor.version
    }

    private func identity() throws -> FileIdentity {
        var info = stat()
        guard stat(destination.path, &info) == 0 else { throw SocketFailure("실행 파일 변경 조회") }
        return FileIdentity(device: info.st_dev, inode: info.st_ino)
    }

    private struct FileIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
    }
}
