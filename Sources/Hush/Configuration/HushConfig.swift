import Foundation

enum HushConfig {
    static let heartbeatInterval: TimeInterval = 3
    static let peerOfflineThreshold: TimeInterval = 12
    static let messageTransmissionCount = 3
    static let messageTransmissionDuration: TimeInterval = 1
}
