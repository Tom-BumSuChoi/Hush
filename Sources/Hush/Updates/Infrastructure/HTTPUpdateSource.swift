import Foundation

struct HTTPUpdateSource: UpdateSource {
    let manifestURL: URL
    let publicKey: Data

    func latestRelease() async throws -> ReleaseDescriptor {
        let data = try await fetch(manifestURL, maximumBytes: 1_048_576)
        return try ReleaseManifest.verify(data, publicKey: publicKey)
    }

    func download(_ descriptor: ReleaseDescriptor) async throws -> Data {
        let data = try await fetch(descriptor.downloadURL, maximumBytes: 100 * 1_048_576)
        try ReleaseManifest.verifyBinary(data, descriptor: descriptor)
        return data
    }

    private func fetch(_ url: URL, maximumBytes: Int) async throws -> Data {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { throw DownloadError.invalidURL }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw DownloadError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw DownloadError.httpStatus(response.statusCode) }
        guard response.expectedContentLength <= maximumBytes else { throw DownloadError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw DownloadError.tooLarge }
            data.append(byte)
        }
        return data
    }

    enum DownloadError: Error {
        case invalidURL
        case invalidResponse
        case httpStatus(Int)
        case tooLarge
    }
}
