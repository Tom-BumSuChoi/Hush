import Foundation

struct MessageSender {
    private var pending: [(deadline: TimeInterval, packet: Data)] = []
    private let send: (Data) throws -> Void

    init(send: @escaping (Data) throws -> Void) {
        self.send = send
    }

    var hasPending: Bool { !pending.isEmpty }
    var nextDeadline: TimeInterval? { pending.first?.deadline }

    mutating func enqueue(_ packet: Data, plan: MessageTransmissionPlan, at uptime: TimeInterval) {
        guard let first = plan.transmissions.first else { return }
        for transmission in plan.transmissions {
            pending.append((uptime + transmission.scheduledAt.timeIntervalSince(first.scheduledAt), packet))
        }
        pending.sort { $0.deadline < $1.deadline }
    }

    mutating func sendDue(at uptime: TimeInterval) throws {
        while let next = pending.first, next.deadline <= uptime {
            pending.removeFirst()
            try send(next.packet)
        }
    }
}
