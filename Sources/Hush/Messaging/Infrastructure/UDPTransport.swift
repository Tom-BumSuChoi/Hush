import Darwin
import Foundation

struct SocketFailure: Error, CustomStringConvertible {
    let operation: String
    let code: Int32

    init(_ operation: String, code: Int32 = errno) {
        self.operation = operation
        self.code = code
    }

    var description: String { "\(operation): \(String(cString: strerror(code)))" }
}

final class UDPTransport {
    let descriptor: Int32

    init(port: UInt16, bindIP: String = "0.0.0.0") throws {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw SocketFailure("UDP 소켓 생성") }
        do {
            var enabled: Int32 = 1
            for option in [SO_REUSEADDR, SO_REUSEPORT, SO_BROADCAST] {
                guard setsockopt(fd, SOL_SOCKET, option, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
                    throw SocketFailure("UDP 소켓 설정")
                }
            }
            var address = try Self.address(ip: bindIP, port: port)
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bound == 0 else { throw SocketFailure("UDP 포트 바인딩") }
            guard fcntl(fd, F_SETFL, O_NONBLOCK) >= 0 else { throw SocketFailure("UDP 비차단 설정") }
            guard fcntl(fd, F_SETFD, FD_CLOEXEC) >= 0 else { throw SocketFailure("UDP 재시작 정리 설정") }
        } catch {
            close(fd)
            throw error
        }
        descriptor = fd
    }

    deinit { close(descriptor) }

    var localPort: UInt16 {
        get throws {
            var address = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let result = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
            }
            guard result == 0 else { throw SocketFailure("UDP 포트 조회") }
            return UInt16(bigEndian: address.sin_port)
        }
    }

    func send(_ data: Data, to ip: String, port: UInt16) throws {
        var destination = try Self.address(ip: ip, port: port)
        let sent = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &destination) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(descriptor, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else { throw SocketFailure("UDP 송신") }
    }

    func receive() throws -> (data: Data, senderIP: String)? {
        var bytes = [UInt8](repeating: 0, count: 65_535)
        var source = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let count = withUnsafeMutablePointer(to: &source) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(descriptor, &bytes, bytes.count, 0, $0, &length)
            }
        }
        if count < 0 {
            if errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR { return nil }
            throw SocketFailure("UDP 수신")
        }
        var output = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &source.sin_addr, &output, socklen_t(output.count)) != nil else {
            throw SocketFailure("발신 IP 확인")
        }
        return (Data(bytes.prefix(count)), String(decoding: output.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
    }

    private static func address(ip: String, port: UInt16) throws -> sockaddr_in {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, ip, &address.sin_addr) == 1 else {
            throw SocketFailure("잘못된 IPv4 주소 \(ip)", code: EINVAL)
        }
        return address
    }
}
