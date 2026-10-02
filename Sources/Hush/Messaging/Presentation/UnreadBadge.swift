import Foundation

// 채팅이 열려 있으면 수신함이 곧 기록에 합쳐지므로, 일정 시간 넘게 남아 있는 메시지만 안 읽음으로 표시합니다.
struct UnreadBadge {
    static let delay: TimeInterval = 1.5
    private var pendingSince: TimeInterval?
    private(set) var shown = 0

    // 표시할 건수가 바뀌었을 때만 새 건수를 반환합니다.
    mutating func update(pending: Int, at uptime: TimeInterval) -> Int? {
        let target: Int
        if pending == 0 {
            pendingSince = nil
            target = 0
        } else {
            let since = pendingSince ?? uptime
            pendingSince = since
            target = uptime - since >= Self.delay ? pending : shown
        }
        guard target != shown else { return nil }
        shown = target
        return target
    }
}
