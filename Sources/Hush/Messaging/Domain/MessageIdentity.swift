import Foundation

struct MessageIdentity: Hashable {
    let senderIP: String
    let createdAt: Date
    let contentHash: String
}
