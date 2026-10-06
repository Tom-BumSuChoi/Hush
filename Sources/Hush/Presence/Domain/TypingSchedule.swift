import Foundation

struct TypingSchedule {
    private var lastTypingSentAt: Date?

    // 입력이 바뀔 때 확인하며, 키를 멈추면 다시 알리지 않아 상대 화면에서 만료되게 둡니다.
    func signal(composing: Bool, at now: Date) -> TypingSignal? {
        guard composing else {
            return lastTypingSentAt == nil ? nil : .stopped
        }
        guard let lastTypingSentAt else {
            return .typing
        }

        return now.timeIntervalSince(lastTypingSentAt) >= HushConfig.typingSignalInterval ? .typing : nil
    }

    mutating func recordSent(_ signal: TypingSignal, at sentAt: Date) {
        lastTypingSentAt = signal == .typing ? sentAt : nil
    }
}
