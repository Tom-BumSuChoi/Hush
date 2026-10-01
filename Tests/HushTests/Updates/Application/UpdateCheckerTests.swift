import CryptoKit
import Foundation
import Testing
@testable import Hush

struct UpdateCheckerTests {
    private final class Server {
        let directory: URL
        let baseURL: URL
        private let process: Process

        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", "-u", "-c", """
            import http.server, functools, sys
            class Handler(http.server.SimpleHTTPRequestHandler):
                def log_message(self, *args): pass
            handler = functools.partial(Handler, directory=sys.argv[1])
            server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
            print(server.server_port, flush=True)
            server.serve_forever()
            """, directory.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try process.run()
            let output = String(decoding: pipe.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let port = UInt16(output) else { throw CLIError("테스트 HTTP 서버 시작 실패") }
            baseURL = URL(string: "http://127.0.0.1:\(port)")!
        }

        func publish(version: String, binary: Data, key: Curve25519.Signing.PrivateKey) throws {
            let descriptor = ReleaseDescriptor(formatVersion: 1, version: version,
                downloadURL: baseURL.appendingPathComponent("Hush"),
                sha256: SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined())
            let payload = try JSONEncoder().encode(descriptor)
            let manifest = try JSONEncoder().encode(ReleaseManifest(payload: payload, signature: key.signature(for: payload)))
            try manifest.write(to: directory.appendingPathComponent("manifest.json"))
            try binary.write(to: directory.appendingPathComponent("Hush"))
        }

        deinit {
            if process.isRunning { process.terminate(); process.waitUntilExit() }
            try? FileManager.default.removeItem(at: directory)
        }
    }

    @Test func 새_버전을_발견하면_실제_HTTP로_검증된_파일을_내려받는다() async throws {
        // Given: 신뢰한 서명으로 새 버전을 제공하는 로컬 HTTP 서버가 있습니다.
        let server = try Server()
        let key = Curve25519.Signing.PrivateKey()
        let binary = Data("release binary".utf8)
        try server.publish(version: "0.2.0", binary: binary, key: key)
        let checker = UpdateChecker(currentVersion: try ReleaseVersion("0.1.0"),
            source: HTTPUpdateSource(manifestURL: server.baseURL.appendingPathComponent("manifest.json"), publicKey: key.publicKey.rawRepresentation))
        // When: 업데이트를 확인합니다.
        let release = try #require(await checker.check())
        // Then: 새 버전과 해시가 검증된 실제 응답 파일을 받습니다.
        #expect(release.descriptor.version == "0.2.0")
        #expect(release.binary == binary)
    }

    @Test func 같은_버전이면_파일을_내려받지_않는다() async throws {
        // Given: 현재와 같은 버전 정보가 있고 파일은 삭제된 서버입니다.
        let server = try Server()
        let key = Curve25519.Signing.PrivateKey()
        try server.publish(version: "0.1.0", binary: Data([1]), key: key)
        try FileManager.default.removeItem(at: server.directory.appendingPathComponent("Hush"))
        let checker = UpdateChecker(currentVersion: try ReleaseVersion("0.1.0"),
            source: HTTPUpdateSource(manifestURL: server.baseURL.appendingPathComponent("manifest.json"), publicKey: key.publicKey.rawRepresentation))
        // When: 업데이트를 확인합니다.
        let release = try await checker.check()
        // Then: 없는 파일에 접근해 실패하지 않고 새 버전 없음으로 반환합니다.
        #expect(release == nil)
    }

    @Test func 실제_응답_파일의_해시가_다르면_교체할_파일을_반환하지_않는다() async throws {
        // Given: 서명한 정보의 파일이 이후 변조된 서버입니다.
        let server = try Server()
        let key = Curve25519.Signing.PrivateKey()
        try server.publish(version: "0.2.0", binary: Data([1]), key: key)
        try Data([2]).write(to: server.directory.appendingPathComponent("Hush"))
        let checker = UpdateChecker(currentVersion: try ReleaseVersion("0.1.0"),
            source: HTTPUpdateSource(manifestURL: server.baseURL.appendingPathComponent("manifest.json"), publicKey: key.publicKey.rawRepresentation))
        // When: 실제 HTTP 응답을 검증합니다.
        // Then: 변조된 파일은 교체 대상으로 반환하지 않습니다.
        await #expect(throws: ReleaseManifest.ManifestError.invalidBinary) { try await checker.check() }
    }
}
