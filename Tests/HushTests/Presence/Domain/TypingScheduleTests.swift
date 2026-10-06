import Foundation
import Testing
@testable import Hush

struct TypingScheduleTests {
    @Test func 메시지를_쓰기_시작하면_바로_입력_중을_알린다() {
        // Given: 아직 입력 중을 알리지 않았습니다.
        let schedule = TypingSchedule()
        let now = Date(timeIntervalSince1970: 1_000)

        // When: 메시지 작성으로 입력이 바뀝니다.
        let signal = schedule.signal(composing: true, at: now)

        // Then: 입력 중을 바로 알립니다.
        #expect(signal == .typing)
    }

    @Test func 입력_중을_알린_뒤_2초_직전에는_다시_알리지_않는다() {
        // Given: 입력 중을 한 번 알렸습니다.
        var schedule = TypingSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordSent(.typing, at: sentAt)

        // When: 1.999초 후에 입력이 다시 바뀝니다.
        let signal = schedule.signal(composing: true, at: sentAt.addingTimeInterval(1.999))

        // Then: 아직 2초가 지나지 않았으므로 알리지 않습니다.
        #expect(signal == nil)
    }

    @Test func 입력_중을_알린_뒤_정확히_2초가_지나면_다시_알린다() {
        // Given: 입력 중을 한 번 알렸습니다.
        var schedule = TypingSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordSent(.typing, at: sentAt)

        // When: 정확히 2초 후에 입력이 다시 바뀝니다.
        let signal = schedule.signal(composing: true, at: sentAt.addingTimeInterval(2))

        // Then: 상대 화면의 표시가 이어지도록 다시 알립니다.
        #expect(signal == .typing)
    }

    @Test func 확인만_하고_보내지_않으면_알릴_시점이_유지된다() {
        // Given: 아직 입력 중을 알리지 않았습니다.
        let schedule = TypingSchedule()
        let now = Date(timeIntervalSince1970: 1_000)

        // When: 실제로 보내지 않고 같은 시각에 두 번 확인합니다.
        let first = schedule.signal(composing: true, at: now)
        let second = schedule.signal(composing: true, at: now)

        // Then: 조회만으로 송신 기록이 바뀌지 않습니다.
        #expect(first == .typing)
        #expect(second == .typing)
    }

    @Test func 입력_중을_알린_적이_없으면_입력을_지워도_정지를_보내지_않는다() {
        // Given: 아직 입력 중을 알리지 않았습니다.
        let schedule = TypingSchedule()

        // When: 메시지 작성이 아닌 입력으로 바뀝니다.
        let signal = schedule.signal(composing: false, at: Date(timeIntervalSince1970: 1_000))

        // Then: 상대에게 알릴 것이 없습니다.
        #expect(signal == nil)
    }

    @Test func 입력_중을_알린_뒤_입력을_지우면_한_번만_정지를_알린다() {
        // Given: 입력 중을 알렸습니다.
        var schedule = TypingSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordSent(.typing, at: sentAt)

        // When: 입력을 지워 정지를 알린 뒤 다시 확인합니다.
        let stopped = schedule.signal(composing: false, at: sentAt.addingTimeInterval(0.5))
        schedule.recordSent(.stopped, at: sentAt.addingTimeInterval(0.5))
        let afterStopped = schedule.signal(composing: false, at: sentAt.addingTimeInterval(1))

        // Then: 정지는 한 번만 알립니다.
        #expect(stopped == .stopped)
        #expect(afterStopped == nil)
    }

    @Test func 정지를_알린_뒤_다시_쓰기_시작하면_바로_입력_중을_알린다() {
        // Given: 입력 중을 알리고 0.5초 후에 정지를 알렸습니다.
        var schedule = TypingSchedule()
        let sentAt = Date(timeIntervalSince1970: 1_000)
        schedule.recordSent(.typing, at: sentAt)
        schedule.recordSent(.stopped, at: sentAt.addingTimeInterval(0.5))

        // When: 2초가 지나기 전에 다시 메시지를 씁니다.
        let signal = schedule.signal(composing: true, at: sentAt.addingTimeInterval(1))

        // Then: 상대 화면에서 표시가 지워졌으므로 바로 다시 알립니다.
        #expect(signal == .typing)
    }
}
