import CryptoKit
import Foundation

enum HushConfig {
    static let version = "0.4.0"
    static let communicationKey = SymmetricKey(data: Data([160, 9, 127, 21, 57, 77, 74, 214, 227, 8, 229, 153, 34, 50, 200, 189, 205, 198, 63, 58, 208, 1, 39, 131, 179, 9, 166, 156, 61, 101, 104, 137]))
    static let udpPort: UInt16 = 49_000
    static let heartbeatInterval: TimeInterval = 3
    static let peerOfflineThreshold: TimeInterval = 12
    static let messageTransmissionCount = 3
    static let messageTransmissionDuration: TimeInterval = 1
    static let updateCheckInterval: TimeInterval = 600
    static let updateManifestURL: URL? = URL(string: "https://gitlab.local/api/v4/projects/11/packages/generic/hush/latest/manifest.json")
    static let updateSigningPublicKeyBase64: String? = "2Nh7R0TJAide4WVjaU4rVFvfSpaO5vwLDQTjur04Kvg="
}
