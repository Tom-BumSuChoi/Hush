import Foundation
import Testing
@testable import Hush

struct RoleLeaseTests {
    @Test func 같은_기록의_같은_역할은_중복_실행할_수_없다() throws {
        // Given: 임시 기록 위치에서 채팅 역할의 잠금을 보유했습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lease = try RoleLease(directory: directory, role: "chat")
        // When: 같은 역할로 다시 실행합니다.
        // Then: 기존 잠금을 유지한 동안 중복 실행을 거부합니다.
        _ = withExtendedLifetime(lease) {
            #expect(throws: CLIError.self) { try RoleLease(directory: directory, role: "chat") }
        }
    }

    @Test func 채팅과_수신기는_같은_기록으로_함께_실행할_수_있다() throws {
        // Given: 임시 기록 위치가 있습니다.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // When: 채팅과 수신 역할을 각각 잠급니다.
        let chat = try RoleLease(directory: directory, role: "chat")
        let receiver = try RoleLease(directory: directory, role: "receive")
        // Then: 다른 역할의 잠금을 동시에 유지할 수 있습니다.
        withExtendedLifetime((chat, receiver)) {}
    }
}
