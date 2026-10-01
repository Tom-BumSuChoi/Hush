import CryptoKit
import Foundation
import Testing
@testable import Hush

struct ExecutableInstallerTests {
    private func compile(version: String, in directory: URL, name: String) throws -> URL {
        let source = directory.appendingPathComponent(name + ".swift")
        try "print(\"\(version)\")\n".write(to: source, atomically: true, encoding: .utf8)
        let output = directory.appendingPathComponent(name)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swiftc", source.path, "-o", output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CLIError("테스트 실행 파일 빌드 실패") }
        return output
    }

    private func release(binary: Data, version: String = "0.2.0") -> DownloadedRelease {
        DownloadedRelease(descriptor: ReleaseDescriptor(formatVersion: 1, version: version,
            downloadURL: URL(string: "http://127.0.0.1/Hush")!,
            sha256: SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()), binary: binary)
    }

    @Test func 실행_가능한_새_버전을_원자적으로_교체하고_실패시_기존_파일로_복원한다() throws {
        // Given: 기존 버전과 새 버전의 실제 Mach-O 실행 파일이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try compile(version: "0.1.0", in: directory, name: "Hush")
        let candidate = try compile(version: "0.2.0", in: directory, name: "candidate")
        let before = try Data(contentsOf: destination)
        let installer = ExecutableInstaller(destination: destination)
        // When: 검증된 새 파일을 교체한 후 재시작 실패를 가정해 되돌립니다.
        let installed = try installer.install(release(binary: Data(contentsOf: candidate)))
        #expect(try ExecutableInstaller.version(at: destination) == "0.2.0")
        try installed.rollback()
        // Then: 실제 실행 버전과 기존 파일 내용이 복원됩니다.
        #expect(try ExecutableInstaller.version(at: destination) == "0.1.0")
        #expect(try Data(contentsOf: destination) == before)
    }

    @Test func 배포_정보와_실제_실행_버전이_다르면_기존_파일을_유지한다() throws {
        // Given: 실제 버전과 광고한 버전이 다른 후보입니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try compile(version: "0.1.0", in: directory, name: "Hush")
        let candidate = try compile(version: "0.2.0", in: directory, name: "candidate")
        let before = try Data(contentsOf: destination)
        // When: 실제 파일보다 높은 버전으로 교체를 시도합니다.
        // Then: 실행 결과가 일치하지 않으므로 교체 전에 거부합니다.
        #expect(throws: ExecutableInstaller.InstallError.versionMismatch) {
            try ExecutableInstaller(destination: destination).install(release(binary: Data(contentsOf: candidate), version: "0.3.0"))
        }
        #expect(try Data(contentsOf: destination) == before)
    }

    @Test func 정상_해시라도_MachO_실행_파일이_아니면_거부한다() throws {
        // Given: 기존 실행 파일과 정상 해시를 가진 일반 데이터입니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("Hush")
        let before = Data("old".utf8)
        try before.write(to: destination)
        // When: 일반 데이터를 업데이트 실행 파일로 설치합니다.
        // Then: 기존 파일을 유지하고 실행하지 않습니다.
        #expect(throws: ExecutableInstaller.InstallError.invalidExecutable) {
            try ExecutableInstaller(destination: destination).install(release(binary: Data("not executable".utf8)))
        }
        #expect(try Data(contentsOf: destination) == before)
    }
}
