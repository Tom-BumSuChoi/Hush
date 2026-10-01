import CryptoKit
import Foundation
import Testing
@testable import Hush

struct ReleaseManifestTests {
    private func descriptor(version: String = "0.2.0", url: String = "https://updates.example.test/Hush") -> ReleaseDescriptor {
        ReleaseDescriptor(formatVersion: 1, version: version, downloadURL: URL(string: url)!,
            sha256: SHA256.hash(data: Data("binary".utf8)).map { String(format: "%02x", $0) }.joined())
    }

    private func signed(_ descriptor: ReleaseDescriptor, key: Curve25519.Signing.PrivateKey) throws -> Data {
        let payload = try JSONEncoder().encode(descriptor)
        return try JSONEncoder().encode(ReleaseManifest(payload: payload, signature: key.signature(for: payload)))
    }

    @Test func 신뢰한_서명으로_버전과_다운로드_주소와_파일_해시를_검증한다() throws {
        // Given: 배포자의 서명 키와 서명한 버전 정보가 있습니다.
        let key = Curve25519.Signing.PrivateKey()
        let release = descriptor()
        let data = try signed(release, key: key)
        // When: 내장할 공개키로 버전 정보와 실제 파일을 검증합니다.
        let verified = try ReleaseManifest.verify(data, publicKey: key.publicKey.rawRepresentation)
        try ReleaseManifest.verifyBinary(Data("binary".utf8), descriptor: verified)
        // Then: 서명한 버전·주소·해시가 유지됩니다.
        #expect(verified.version == release.version)
        #expect(verified.downloadURL == release.downloadURL)
        #expect(verified.sha256 == release.sha256)
    }

    @Test func 다른_서명자와_변조된_버전_정보는_거부한다() throws {
        // Given: 정상 버전 정보와 다른 서명자가 있습니다.
        let key = Curve25519.Signing.PrivateKey()
        let other = Curve25519.Signing.PrivateKey()
        let data = try signed(descriptor(), key: key)
        var manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)
        let changed = try JSONEncoder().encode(descriptor(version: "99.0.0"))
        manifest = ReleaseManifest(payload: changed, signature: manifest.signature)
        let tampered = try JSONEncoder().encode(manifest)
        // When: 다른 공개키와 변조된 정보로 검증합니다.
        // Then: 정상 업데이트로 받아들이지 않습니다.
        #expect(throws: ReleaseManifest.ManifestError.invalidSignature) {
            try ReleaseManifest.verify(data, publicKey: other.publicKey.rawRepresentation)
        }
        #expect(throws: ReleaseManifest.ManifestError.invalidSignature) {
            try ReleaseManifest.verify(tampered, publicKey: key.publicKey.rawRepresentation)
        }
    }

    @Test func 서명한_파일_해시와_다운로드_내용이_다르면_교체_대상이_아니다() {
        // Given: 배포자가 서명한 파일 해시가 있습니다.
        let release = descriptor()
        // When: 변조된 파일 내용을 검증합니다.
        // Then: 파일 교체 전에 거부합니다.
        #expect(throws: ReleaseManifest.ManifestError.invalidBinary) {
            try ReleaseManifest.verifyBinary(Data("tampered".utf8), descriptor: release)
        }
    }

    @Test func 지원하지_않는_주소와_버전은_서명되어도_거부한다() throws {
        // Given: 서명되어 있지만 지원하지 않는 배포 정보가 있습니다.
        let key = Curve25519.Signing.PrivateKey()
        let fileURL = try signed(descriptor(url: "file:///private/tmp/Hush"), key: key)
        let version = try signed(descriptor(version: "0.2.0-beta"), key: key)
        // When: 버전 정보를 검증합니다.
        // Then: 허용한 네트워크 주소와 안정 버전만 사용합니다.
        #expect(throws: ReleaseManifest.ManifestError.invalidManifest) {
            try ReleaseManifest.verify(fileURL, publicKey: key.publicKey.rawRepresentation)
        }
        #expect(throws: ReleaseVersion.VersionError.invalidFormat) {
            try ReleaseManifest.verify(version, publicKey: key.publicKey.rawRepresentation)
        }
    }
}
