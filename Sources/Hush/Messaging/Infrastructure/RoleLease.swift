import Darwin
import Foundation

final class RoleLease {
    private let descriptor: Int32

    init(directory: URL, role: String) throws {
        let fd = open(directory.appendingPathComponent(".\(role).lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw SocketFailure("실행 역할 잠금 파일 생성") }
        guard fcntl(fd, F_SETFD, FD_CLOEXEC) == 0, flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let failure = errno
            close(fd)
            if failure == EWOULDBLOCK { throw CLIError("이 기록을 사용하는 \(role) 프로세스가 이미 실행 중입니다") }
            throw SocketFailure("실행 역할 잠금", code: failure)
        }
        descriptor = fd
    }

    deinit { close(descriptor) }
}
