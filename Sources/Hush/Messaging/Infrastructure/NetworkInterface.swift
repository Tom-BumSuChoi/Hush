import Darwin
import Foundation

struct NetworkInterface: Equatable {
    let name: String
    let ip: String
    let broadcastIP: String

    static func discover() throws -> [NetworkInterface] {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { throw SocketFailure("네트워크 인터페이스 조회") }
        defer { freeifaddrs(interfaces) }
        var result: [NetworkInterface] = []
        var current = interfaces
        while let pointer = current {
            let entry = pointer.pointee
            defer { current = entry.ifa_next }
            guard let address = entry.ifa_addr, let mask = entry.ifa_netmask,
                  address.pointee.sa_family == UInt8(AF_INET),
                  entry.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.ifa_flags & UInt32(IFF_BROADCAST) != 0,
                  entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            var ip = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
            let netmask = UnsafeRawPointer(mask).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
            var broadcast = in_addr(s_addr: ip.s_addr | ~netmask.s_addr)
            var ipText = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var broadcastText = ipText
            guard inet_ntop(AF_INET, &ip, &ipText, socklen_t(ipText.count)) != nil,
                  inet_ntop(AF_INET, &broadcast, &broadcastText, socklen_t(broadcastText.count)) != nil else { continue }
            result.append(NetworkInterface(name: String(cString: entry.ifa_name),
                ip: String(decoding: ipText.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self),
                broadcastIP: String(decoding: broadcastText.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)))
        }
        return result
    }
}
