// SourceIDResolver 행동 테스트 — issue #6 (S5: PreferenceStore + resolveSourceID)
import Testing
@testable import SoloTapDetectorCore

@Suite struct SourceIDResolverTests {

    // MARK: - Behavior 1: stored 유효 + available에 포함 → stored 반환

    @Test func storedValid_inAvailable_returnsStored() {
        let result = SourceIDResolver.resolveSourceID(
            stored: "com.apple.keylayout.ABC",
            available: ["com.apple.keylayout.ABC", "com.apple.inputmethod.Korean.2SetKorean"],
            fallback: "com.apple.inputmethod.Korean.2SetKorean"
        )
        #expect(result == "com.apple.keylayout.ABC")
    }

    // MARK: - Behavior 2: stored nil + fallback available에 포함 → fallback 반환

    @Test func storedNil_fallbackInAvailable_returnsFallback() {
        let result = SourceIDResolver.resolveSourceID(
            stored: nil,
            available: ["com.apple.keylayout.ABC", "com.apple.inputmethod.Korean.2SetKorean"],
            fallback: "com.apple.keylayout.ABC"
        )
        #expect(result == "com.apple.keylayout.ABC")
    }
}
