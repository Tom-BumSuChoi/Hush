import Foundation
import SystemConfiguration

struct NetworkPreference: Equatable {
    let wifiNames: Set<String>
    let primaryName: String?

    static func current() -> NetworkPreference {
        let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        let wifiNames = interfaces.filter {
            SCNetworkInterfaceGetInterfaceType($0).map { $0 as String } == kSCNetworkInterfaceTypeIEEE80211 as String
        }.compactMap { SCNetworkInterfaceGetBSDName($0).map { $0 as String } }
        let store = SCDynamicStoreCreate(nil, "Hush" as CFString, nil, nil)
        let global = store.flatMap { SCDynamicStoreCopyValue($0, "State:/Network/Global/IPv4" as CFString) } as? [String: Any]
        return NetworkPreference(wifiNames: Set(wifiNames), primaryName: global?["PrimaryInterface"] as? String)
    }
}
