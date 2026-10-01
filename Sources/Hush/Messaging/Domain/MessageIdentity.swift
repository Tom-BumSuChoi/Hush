import Foundation

struct MessageIdentity: Equatable {
    let senderIP: String
    let createdAt: Date
    let contentHash: String
}
