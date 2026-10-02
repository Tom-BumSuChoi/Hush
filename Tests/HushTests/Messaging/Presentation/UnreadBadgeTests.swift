import Foundation
import Testing
@testable import Hush

struct UnreadBadgeTests {
    @Test func 수신함에_잠시_머문_메시지는_표시하지_않는다() {
        // Given: 채팅이 열려 있어 수신함이 0.5초 만에 합쳐집니다.
        var badge = UnreadBadge()
        // When: 메시지가 쌓였다가 지연 시간 전에 비워집니다.
        let arrived = badge.update(pending: 1, at: 10)
        let merged = badge.update(pending: 0, at: 10.5)
        // Then: 표시가 한 번도 바뀌지 않습니다.
        #expect(arrived == nil)
        #expect(merged == nil)
        #expect(badge.shown == 0)
    }

    @Test func 지연_시간이_지나도_남아_있으면_안_읽은_건수를_표시한다() {
        // Given: 채팅이 닫혀 있어 수신함이 합쳐지지 않습니다.
        var badge = UnreadBadge()
        _ = badge.update(pending: 1, at: 10)
        // When: 1.5초 경계 직전과 직후, 추가 메시지 도착을 확인합니다.
        let before = badge.update(pending: 1, at: 11.49)
        let after = badge.update(pending: 1, at: 11.5)
        let more = badge.update(pending: 3, at: 12)
        // Then: 경계를 넘은 뒤 건수를 표시하고, 이후 늘어난 건수는 바로 반영합니다.
        #expect(before == nil)
        #expect(after == 1)
        #expect(more == 3)
    }

    @Test func 기록에_합쳐지면_바로_표시를_끈다() {
        // Given: 안 읽은 메시지 두 건을 표시 중입니다.
        var badge = UnreadBadge()
        _ = badge.update(pending: 2, at: 0)
        _ = badge.update(pending: 2, at: 2)
        // When: hush로 기록을 열어 수신함이 비워집니다.
        let cleared = badge.update(pending: 0, at: 2.5)
        // Then: 지연 없이 표시를 끄고, 다음 메시지는 다시 지연 후 표시합니다.
        #expect(cleared == 0)
        #expect(badge.update(pending: 1, at: 3) == nil)
        #expect(badge.update(pending: 1, at: 4.5) == 1)
    }

    @Test func 메뉴_막대에는_건수만_표시하고_큰_수는_줄인다() {
        // Given: 안 읽은 건수가 없거나, 한 자리거나, 두 자리입니다.
        // When: 메뉴 문구와 배지 글자를 만듭니다.
        // Then: 내용 없이 건수만 보여 주고 열 건 이상은 9+로 줄입니다.
        #expect(MenuBarIndicator.summary(unread: 0) == "새 메시지 없음")
        #expect(MenuBarIndicator.summary(unread: 2) == "새 메시지 2건")
        #expect(MenuBarIndicator.badgeText(unread: 3) == "3")
        #expect(MenuBarIndicator.badgeText(unread: 12) == "9+")
    }
}
