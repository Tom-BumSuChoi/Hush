import Testing
@testable import Hush

struct UpdateScheduleTests {
    @Test func 실행_시_확인하고_이후_10분부터_다시_확인한다() {
        // Given: 아직 업데이트를 확인하지 않은 실행입니다.
        var schedule = UpdateSchedule()
        #expect(schedule.shouldCheck(at: 100))
        // When: 첫 확인 시각을 기록합니다.
        schedule.recordCheck(at: 100)
        // Then: 10분 직전에는 기다리고 정확히 10분부터 다시 확인합니다.
        #expect(!schedule.shouldCheck(at: 699.999))
        #expect(schedule.shouldCheck(at: 700))
    }

    @Test func 다시_확인하면_마지막_확인부터_10분을_계산한다() {
        // Given: 실행 시와 10분 뒤에 확인했습니다.
        var schedule = UpdateSchedule()
        schedule.recordCheck(at: 100)
        schedule.recordCheck(at: 700)
        // When: 두 번째 확인 이후의 경계를 조회합니다.
        // Then: 마지막 확인을 기준으로 다음 확인을 계획합니다.
        #expect(!schedule.shouldCheck(at: 1_299.999))
        #expect(schedule.shouldCheck(at: 1_300))
    }
}
