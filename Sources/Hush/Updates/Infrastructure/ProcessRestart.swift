import Darwin

enum ProcessRestart {
    static func restart(_ installed: InstalledExecutable, arguments: [String]) throws -> Never {
        var argv = ([installed.url.path] + arguments).map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { free($0) } }
        execv(installed.url.path, &argv)
        let failure = errno
        try installed.rollback()
        throw SocketFailure("업데이트 재시작", code: failure)
    }
}
