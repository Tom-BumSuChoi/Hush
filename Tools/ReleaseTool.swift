import CryptoKit
import Darwin
import Foundation

@main
struct ReleaseTool {
    static func main() {
        do { try run() }
        catch {
            FileHandle.standardError.write(Data("ReleaseTool: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        switch args.first {
        case "keygen" where args.count == 2:
            let directory = URL(fileURLWithPath: args[1], isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let key = Curve25519.Signing.PrivateKey()
            let path = directory.appendingPathComponent("signing-private-key")
            let fd = open(path.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
            guard fd >= 0 else { throw ToolError.keyFileExistsOrUnavailable }
            close(fd)
            try key.rawRepresentation.write(to: path)
            print(key.publicKey.rawRepresentation.base64EncodedString())
        case "manifest" where args.count == 6:
            _ = try ReleaseVersion(args[2])
            guard let url = URL(string: args[3]), ["http", "https"].contains(url.scheme ?? ""), url.host != nil else {
                throw ToolError.invalidArguments
            }
            let binary = try Data(contentsOf: URL(fileURLWithPath: args[1]))
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(contentsOf: URL(fileURLWithPath: args[4])))
            let descriptor = ReleaseDescriptor(formatVersion: 1, version: args[2], downloadURL: url,
                sha256: SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined())
            let payload = try JSONEncoder().encode(descriptor)
            let manifest = try JSONEncoder().encode(ReleaseManifest(payload: payload, signature: key.signature(for: payload)))
            _ = try ReleaseManifest.verify(manifest, publicKey: key.publicKey.rawRepresentation)
            try manifest.write(to: URL(fileURLWithPath: args[5]), options: .atomic)
        case "verify" where args.count == 4:
            guard let publicKey = Data(base64Encoded: args[2]) else { throw ToolError.invalidArguments }
            let descriptor = try ReleaseManifest.verify(Data(contentsOf: URL(fileURLWithPath: args[1])), publicKey: publicKey)
            try ReleaseManifest.verifyBinary(Data(contentsOf: URL(fileURLWithPath: args[3])), descriptor: descriptor)
            print(descriptor.version)
        default:
            print("""
            ReleaseTool keygen 키_디렉터리
            ReleaseTool manifest 실행파일 버전 다운로드_URL 개인키_파일 매니페스트_파일
            ReleaseTool verify 매니페스트_파일 공개키_base64 실행파일
            """)
            throw ToolError.invalidArguments
        }
    }

    enum ToolError: Error {
        case invalidArguments
        case keyFileExistsOrUnavailable
    }
}
