import Darwin

final class TerminalMode {
    private var original = termios()
    private var restored = false

    init() throws {
        guard tcgetattr(STDIN_FILENO, &original) == 0 else { throw SocketFailure("터미널 상태 조회") }
        var settings = original
        settings.c_lflag &= ~tcflag_t(ECHO | ICANON)
        withUnsafeMutableBytes(of: &settings.c_cc) {
            $0[Int(VMIN)] = 1
            $0[Int(VTIME)] = 0
        }
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &settings) == 0 else { throw SocketFailure("터미널 입력 설정") }
    }

    func restore() {
        if !restored { tcsetattr(STDIN_FILENO, TCSAFLUSH, &original); restored = true }
    }

    deinit { restore() }
}
