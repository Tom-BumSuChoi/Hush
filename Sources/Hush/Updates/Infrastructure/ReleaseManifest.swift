import CryptoKit
import Foundation

struct ReleaseManifest: Codable {
    let payload: Data
    let signature: Data

    static func verify(_ data: Data, publicKey: Data) throws -> ReleaseDescriptor {
        guard data.count <= 1_048_576 else { throw ManifestError.invalidManifest }
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        guard key.isValidSignature(manifest.signature, for: manifest.payload) else {
            throw ManifestError.invalidSignature
        }
        let descriptor = try JSONDecoder().decode(ReleaseDescriptor.self, from: manifest.payload)
        guard descriptor.formatVersion == 1,
              ["https", "http"].contains(descriptor.downloadURL.scheme?.lowercased() ?? ""),
              descriptor.downloadURL.host != nil,
              descriptor.downloadURL.user == nil, descriptor.downloadURL.password == nil,
              descriptor.sha256.utf8.count == 64,
              descriptor.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw ManifestError.invalidManifest
        }
        _ = try ReleaseVersion(descriptor.version)
        return descriptor
    }

    static func verifyBinary(_ binary: Data, descriptor: ReleaseDescriptor) throws {
        let digest = SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()
        guard digest == descriptor.sha256 else { throw ManifestError.invalidBinary }
    }

    enum ManifestError: Error {
        case invalidManifest
        case invalidSignature
        case invalidBinary
    }
}
