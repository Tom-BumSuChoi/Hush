import Darwin
import Foundation

// 터미널 테마의 기본 색(ansi), 색 없음(terminalDefault), 팔레트에서 고른 색(rgb) 가운데 하나입니다.
enum TextColor: Codable, Equatable {
    case terminalDefault
    case ansi(normal: Int, bright: Int)
    case rgb(red: Int, green: Int, blue: Int)

    static let green = TextColor.ansi(normal: 32, bright: 92)

    var isValid: Bool {
        switch self {
        case .terminalDefault: true
        case .ansi(let normal, let bright): (30...37).contains(normal) && (90...97).contains(bright)
        case .rgb(let red, let green, let blue): [red, green, blue].allSatisfy { (0...255).contains($0) }
        }
    }
}

// 글자 색은 비밀이 아니므로 기록 위치에 평문 설정 파일로 둡니다.
enum SettingsStore {
    private struct Settings: Codable {
        let version: Int
        let textColor: TextColor
    }

    static func url(in directory: URL) -> URL { directory.appendingPathComponent("settings.json") }

    // 파일이 없거나 읽을 수 없으면 기본 초록을 사용합니다.
    static func textColor(in directory: URL) -> TextColor {
        guard let data = try? Data(contentsOf: url(in: directory)),
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              settings.version == 1, settings.textColor.isValid else { return .green }
        return settings.textColor
    }

    static func save(textColor: TextColor, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(Settings(version: 1, textColor: textColor))
        let temporary = directory.appendingPathComponent(".settings-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw SocketFailure("설정 임시 파일 생성")
        }
        guard rename(temporary.path, url(in: directory).path) == 0 else {
            let failure = errno
            try? FileManager.default.removeItem(at: temporary)
            throw SocketFailure("설정 파일 교체", code: failure)
        }
    }
}
