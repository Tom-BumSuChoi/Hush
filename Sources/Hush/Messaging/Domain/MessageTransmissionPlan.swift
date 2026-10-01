import Foundation

struct MessageTransmissionPlan {
    let transmissions: [Transmission]

    init(identity: MessageIdentity, startedAt: Date) {
        let interval = HushConfig.messageTransmissionDuration / Double(HushConfig.messageTransmissionCount - 1)
        transmissions = (0..<HushConfig.messageTransmissionCount).map { index in
            Transmission(
                identity: identity,
                scheduledAt: startedAt.addingTimeInterval(Double(index) * interval)
            )
        }
    }

    struct Transmission {
        let identity: MessageIdentity
        let scheduledAt: Date
    }
}
