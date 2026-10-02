import Foundation

// Hush 출력의 글자 색이며, 내 메시지는 같은 계열의 밝은 색에 굵게 구분합니다.
struct TerminalPalette: Equatable {
    struct Preset {
        let title: String
        let color: TextColor
        // 메뉴에 보여 줄 견본 색이며, 터미널 기본색은 견본이 없습니다.
        let swatch: (red: Int, green: Int, blue: Int)?
    }

    static let presets = [
        Preset(title: "초록", color: .green, swatch: (46, 189, 59)),
        Preset(title: "노랑", color: .ansi(normal: 33, bright: 93), swatch: (222, 190, 40)),
        Preset(title: "청록", color: .ansi(normal: 36, bright: 96), swatch: (40, 180, 200)),
        Preset(title: "흰색", color: .ansi(normal: 37, bright: 97), swatch: (235, 235, 235)),
        Preset(title: "터미널 기본색", color: .terminalDefault, swatch: nil),
    ]

    // CLI 출력은 한 스레드에서만 하며, 시작할 때와 메뉴 막대에서 색을 바꿨을 때 갱신합니다.
    nonisolated(unsafe) static var current = TerminalPalette(color: .green, trueColor: false)

    let color: TextColor
    let trueColor: Bool

    init(color: TextColor, trueColor: Bool) {
        self.color = color
        self.trueColor = trueColor
    }

    func normal(_ text: String) -> String {
        switch color {
        case .terminalDefault: text
        case .ansi(let normal, _): Self.wrap(text, code: "\(normal)")
        case .rgb(let red, let green, let blue): Self.wrap(text, code: rgbCode(red, green, blue))
        }
    }

    func own(_ text: String) -> String {
        switch color {
        case .terminalDefault: Self.wrap(text, code: "1")
        case .ansi(_, let bright): Self.wrap(text, code: "1;\(bright)")
        case .rgb(let red, let green, let blue):
            Self.wrap(text, code: "1;" + rgbCode(Self.lighten(red), Self.lighten(green), Self.lighten(blue)))
        }
    }

    // 정확한 색을 지원한다고 알리는 터미널만 24비트 색을 쓰고, 나머지는 가장 가까운 256색으로 표시합니다.
    static func supportsTrueColor(environment: [String: String]) -> Bool {
        ["truecolor", "24bit"].contains(environment["COLORTERM"]?.lowercased() ?? "")
            || ["iTerm.app", "vscode"].contains(environment["TERM_PROGRAM"] ?? "")
    }

    static func ansi256(red: Int, green: Int, blue: Int) -> Int {
        let level = { (value: Int) in Int((Double(value) / 255 * 5).rounded()) }
        return 16 + 36 * level(red) + 6 * level(green) + level(blue)
    }

    // 메뉴 막대에서 바꾼 설정을 읽어 반영하며, 색이 바뀌었으면 true를 반환합니다.
    @discardableResult
    static func reload(from directory: URL, environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        let palette = TerminalPalette(color: SettingsStore.textColor(in: directory), trueColor: supportsTrueColor(environment: environment))
        guard palette != current else { return false }
        current = palette
        return true
    }

    private func rgbCode(_ red: Int, _ green: Int, _ blue: Int) -> String {
        trueColor ? "38;2;\(red);\(green);\(blue)" : "38;5;\(Self.ansi256(red: red, green: green, blue: blue))"
    }

    private static func lighten(_ value: Int) -> Int {
        Int((Double(value) + Double(255 - value) * 0.35).rounded())
    }

    private static func wrap(_ text: String, code: String) -> String {
        "\u{1B}[\(code)m\(text)\u{1B}[0m"
    }
}
