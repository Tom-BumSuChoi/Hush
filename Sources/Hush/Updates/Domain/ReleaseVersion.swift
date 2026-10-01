struct ReleaseVersion: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ text: String) throws {
        let components = text.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { throw VersionError.invalidFormat }
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == 3, numbers.allSatisfy({ $0 >= 0 }),
              zip(components, numbers).allSatisfy({ String($0.0) == String($0.1) }) else {
            throw VersionError.invalidFormat
        }
        major = numbers[0]
        minor = numbers[1]
        patch = numbers[2]
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    enum VersionError: Error { case invalidFormat }
}
