import CryptoKit
import Foundation

@main
struct PacketFixture {
    static func main() throws {
        let args = CommandLine.arguments
        let codec = PacketCodec(key: HushConfig.communicationKey)
        switch args[1] {
        case "message":
            let message = ChatMessage(identity: MessageIdentity(senderIP: "127.0.0.1",
                createdAt: Date(timeIntervalSince1970: Double(args[3])!), contentHash: PacketCodec.contentHash(args[2])), content: args[2])
            print(try codec.encode(.message(message)).base64EncodedString())
        case "heartbeat": print(try codec.encode(.heartbeat).base64EncodedString())
        case "decode":
            switch try codec.decode(Data(base64Encoded: args[2])!, senderIP: "127.0.0.1") {
            case .heartbeat: print("heartbeat")
            case .message(let message): print(message.content)
            }
        case "history":
            let store = try HistoryStore(directory: URL(fileURLWithPath: args[2]), password: args[3])
            let records = try store.load()
            FileHandle.standardOutput.write(try JSONEncoder().encode(records))
        default: fatalError("지원하지 않는 테스트 명령")
        }
    }
}
