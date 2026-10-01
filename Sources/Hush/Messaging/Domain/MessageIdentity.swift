import Foundation

struct MessageIdentity: Hashable, Codable, Sendable {
    let senderIP: String
    let createdAt: Date
    let contentHash: String
}
