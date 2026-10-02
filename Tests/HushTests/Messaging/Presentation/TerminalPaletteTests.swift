import Foundation
import Testing
@testable import Hush

struct TerminalPaletteTests {
    @Test func 기본_초록은_지금과_같은_색으로_표시한다() {
        // Given: 설정하지 않은 기본 초록입니다.
        let palette = TerminalPalette(color: .green, trueColor: true)
        // When: 일반 글과 내 메시지를 표시합니다.
        // Then: 터미널 테마의 초록과 밝은 초록 굵게를 그대로 사용합니다.
        #expect(palette.normal("안녕") == "\u{1B}[32m안녕\u{1B}[0m")
        #expect(palette.own("안녕") == "\u{1B}[1;92m안녕\u{1B}[0m")
    }

    @Test func 터미널_기본색은_색_없이_내_메시지만_굵게_구분한다() {
        // Given: 밝은 테마 사용자를 위한 터미널 기본색입니다.
        let palette = TerminalPalette(color: .terminalDefault, trueColor: false)
        // When: 일반 글과 내 메시지를 표시합니다.
        // Then: 일반 글에는 색 코드를 넣지 않고 내 메시지는 굵게만 표시합니다.
        #expect(palette.normal("안녕") == "안녕")
        #expect(palette.own("안녕") == "\u{1B}[1m안녕\u{1B}[0m")
    }

    @Test func 직접_고른_색은_정확한_색을_쓰고_내_메시지는_더_밝게_표시한다() {
        // Given: 팔레트에서 주황을 골랐고 터미널이 정확한 색을 지원합니다.
        let palette = TerminalPalette(color: .rgb(red: 255, green: 136, blue: 0), trueColor: true)
        // When: 일반 글과 내 메시지를 표시합니다.
        // Then: 고른 색 그대로와, 흰색 쪽으로 35% 밝힌 굵은 색을 사용합니다.
        #expect(palette.normal("안녕") == "\u{1B}[38;2;255;136;0m안녕\u{1B}[0m")
        #expect(palette.own("안녕") == "\u{1B}[1;38;2;255;178;89m안녕\u{1B}[0m")
    }

    @Test func 정확한_색을_지원하지_않는_터미널은_가까운_256색으로_표시한다() {
        // Given: 팔레트에서 주황을 골랐지만 터미널이 정확한 색을 알리지 않습니다.
        let palette = TerminalPalette(color: .rgb(red: 255, green: 136, blue: 0), trueColor: false)
        // When: 일반 글을 표시합니다.
        // Then: 6단계 색 공간의 가장 가까운 칸으로 바꿉니다.
        #expect(palette.normal("안녕") == "\u{1B}[38;5;214m안녕\u{1B}[0m")
        #expect(TerminalPalette.ansi256(red: 0, green: 0, blue: 0) == 16)
        #expect(TerminalPalette.ansi256(red: 255, green: 255, blue: 255) == 231)
    }

    @Test func 터미널이_알리는_정보로_정확한_색_지원을_판별한다() {
        // Given: 여러 터미널의 환경 변수가 있습니다.
        // When: 정확한 색 지원 여부를 판별합니다.
        // Then: COLORTERM이나 iTerm2·VS Code만 지원으로 보고 나머지는 256색으로 처리합니다.
        #expect(TerminalPalette.supportsTrueColor(environment: ["COLORTERM": "truecolor"]))
        #expect(TerminalPalette.supportsTrueColor(environment: ["COLORTERM": "24bit"]))
        #expect(TerminalPalette.supportsTrueColor(environment: ["TERM_PROGRAM": "iTerm.app"]))
        #expect(TerminalPalette.supportsTrueColor(environment: ["TERM_PROGRAM": "vscode"]))
        #expect(!TerminalPalette.supportsTrueColor(environment: ["TERM_PROGRAM": "Apple_Terminal"]))
        #expect(!TerminalPalette.supportsTrueColor(environment: [:]))
    }

    @Test func 정해_둔_색은_초록부터_서로_다른_색으로_제공한다() {
        // Given: 메뉴 막대에 보여 줄 정해 둔 색 목록이 있습니다.
        let colors = TerminalPalette.presets.map(\.color)
        // When: 목록을 확인합니다.
        // Then: 기본 초록이 처음이고, 모든 색이 서로 다르며 유효합니다.
        #expect(colors.first == .green)
        #expect(colors.contains(.terminalDefault))
        #expect(colors.allSatisfy { $0.isValid })
        let distinct = colors.enumerated().allSatisfy { index, color in !colors[(index + 1)...].contains(color) }
        #expect(distinct)
    }
}
