import Foundation

struct UpdateSchedule {
    private var lastCheckedAt: TimeInterval?

    func shouldCheck(at uptime: TimeInterval) -> Bool {
        lastCheckedAt.map { uptime - $0 >= HushConfig.updateCheckInterval } ?? true
    }

    mutating func recordCheck(at uptime: TimeInterval) {
        lastCheckedAt = uptime
    }
}
