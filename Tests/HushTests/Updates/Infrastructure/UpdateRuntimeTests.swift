import CryptoKit
import Foundation
import Testing
@testable import Hush

struct UpdateRuntimeTests {
    private struct FixedSource: UpdateSource {
        let version: String
        let binary: Data

        func latestRelease() async throws -> ReleaseDescriptor {
            ReleaseDescriptor(formatVersion: 1, version: version, downloadURL: URL(string: "http://127.0.0.1/Hush")!,
                sha256: SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined())
        }

        func download(_ descriptor: ReleaseDescriptor) async throws -> Data { binary }
    }

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

    @Test func 수동_업데이트는_새_버전을_기다려_설치하고_설치한_버전을_알린다() throws {
        // Given: 0.1.0이 설치되어 있고 배포 주소에 검증 가능한 0.2.0이 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try compile(version: "0.1.0", in: directory, name: "Hush")
        let candidate = try Data(contentsOf: compile(version: "0.2.0", in: directory, name: "candidate"))
        let runtime = UpdateRuntime(checker: UpdateChecker(currentVersion: try ReleaseVersion("0.1.0"),
            source: FixedSource(version: "0.2.0", binary: candidate)), destination: destination)
        // When: 수동 업데이트를 실행합니다.
        let installed = try runtime.upgradeNow()
        // Then: 설치가 끝난 뒤 새 버전을 반환하고 실제 실행 파일이 교체됩니다.
        #expect(installed == "0.2.0")
        #expect(try ExecutableInstaller.version(at: destination) == "0.2.0")
        #expect(try ExecutableInstaller.version(at: URL(fileURLWithPath: destination.path + ".previous")) == "0.1.0")
    }

    @Test func 이미_최신이면_수동_업데이트가_파일을_바꾸지_않는다() throws {
        // Given: 설치된 버전과 배포된 버전이 같습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try compile(version: "0.1.0", in: directory, name: "Hush")
        let before = try Data(contentsOf: destination)
        let runtime = UpdateRuntime(checker: UpdateChecker(currentVersion: try ReleaseVersion("0.1.0"),
            source: FixedSource(version: "0.1.0", binary: before)), destination: destination)
        // When: 수동 업데이트를 실행합니다.
        let installed = try runtime.upgradeNow()
        // Then: 최신이라고 알리고 기존 파일을 그대로 둡니다.
        #expect(installed == nil)
        #expect(try Data(contentsOf: destination) == before)
        #expect(!FileManager.default.fileExists(atPath: destination.path + ".previous"))
    }
}
