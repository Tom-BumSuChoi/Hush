import Foundation

protocol UpdateSource: Sendable {
    func latestRelease() async throws -> ReleaseDescriptor
    func download(_ descriptor: ReleaseDescriptor) async throws -> Data
}

struct DownloadedRelease: Sendable {
    let descriptor: ReleaseDescriptor
    let binary: Data
}

struct UpdateChecker: Sendable {
    let currentVersion: ReleaseVersion
    let source: any UpdateSource

    func check() async throws -> DownloadedRelease? {
        let descriptor = try await source.latestRelease()
        guard try ReleaseVersion(descriptor.version) > currentVersion else { return nil }
        let binary = try await source.download(descriptor)
        return DownloadedRelease(descriptor: descriptor, binary: binary)
    }
}
