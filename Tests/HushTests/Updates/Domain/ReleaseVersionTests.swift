import Testing
@testable import Hush

struct ReleaseVersionTests {
    @Test func 버전은_문자열_순서가_아닌_숫자로_비교한다() throws {
        // Given: 자릿수가 다른 버전들이 있습니다.
        let current = try ReleaseVersion("1.9.0")
        // When: 새 버전들과 비교합니다.
        // Then: 주·부·패치 버전의 숫자 순서를 적용합니다.
        #expect(try current < ReleaseVersion("1.10.0"))
        #expect(try ReleaseVersion("1.99.99") < ReleaseVersion("2.0.0"))
        #expect(try ReleaseVersion("1.0.9") < ReleaseVersion("1.0.10"))
        #expect(try current == ReleaseVersion("1.9.0"))
    }

    @Test func 지원하지_않는_버전_형식은_거부한다() {
        // Given: 모호하거나 지원하지 않는 버전 문자열이 있습니다.
        let versions = ["1.0", "1.0.0.1", "1.-1.0", "01.0.0", "1.0.0-beta", "", "1..0"]
        // When: 버전으로 해석합니다.
        // Then: 안정 버전의 세 숫자 형식만 받아들입니다.
        for version in versions {
            #expect(throws: ReleaseVersion.VersionError.invalidFormat) { try ReleaseVersion(version) }
        }
    }
}
