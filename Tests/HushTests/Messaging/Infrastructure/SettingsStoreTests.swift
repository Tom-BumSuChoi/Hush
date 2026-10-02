import Foundation
import Testing
@testable import Hush

struct SettingsStoreTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func 설정이_없으면_기본_초록을_사용한다() {
        // Given: 설정 파일이 없는 기록 위치입니다.
        let directory = temporaryDirectory()
        // When: 글자 색을 읽습니다.
        // Then: 기본 초록을 사용합니다.
        #expect(SettingsStore.textColor(in: directory) == .green)
    }

    @Test func 고른_색을_저장하고_다시_읽는다() throws {
        // Given: 메뉴 막대에서 색을 고른 기록 위치입니다.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // When: 직접 고른 색과 터미널 기본색을 차례로 저장하고 읽습니다.
        try SettingsStore.save(textColor: .rgb(red: 255, green: 136, blue: 0), in: directory)
        let custom = SettingsStore.textColor(in: directory)
        try SettingsStore.save(textColor: .terminalDefault, in: directory)
        let plain = SettingsStore.textColor(in: directory)
        // Then: 저장한 색을 그대로 읽고 파일은 본인만 읽을 수 있습니다.
        #expect(custom == .rgb(red: 255, green: 136, blue: 0))
        #expect(plain == .terminalDefault)
        let permissions = try FileManager.default.attributesOfItem(atPath: SettingsStore.url(in: directory).path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func 손상되거나_범위를_벗어난_설정은_기본_초록으로_돌아간다() throws {
        // Given: 깨진 설정과 잘못된 색 번호가 들어 있는 설정 파일이 있습니다.
        let broken = temporaryDirectory()
        let invalid = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: broken)
            try? FileManager.default.removeItem(at: invalid)
        }
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: SettingsStore.url(in: broken))
        try SettingsStore.save(textColor: .ansi(normal: 5, bright: 200), in: invalid)
        // When: 글자 색을 읽습니다.
        // Then: 터미널에 잘못된 제어 코드를 내보내지 않도록 기본 초록을 사용합니다.
        #expect(SettingsStore.textColor(in: broken) == .green)
        #expect(SettingsStore.textColor(in: invalid) == .green)
    }
}
