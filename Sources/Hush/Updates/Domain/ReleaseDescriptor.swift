import Foundation

struct ReleaseDescriptor: Codable, Sendable {
    let formatVersion: Int
    let version: String
    let downloadURL: URL
    let sha256: String
}
