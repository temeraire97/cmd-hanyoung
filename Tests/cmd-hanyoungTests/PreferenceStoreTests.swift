// PreferenceStore 행동 테스트 — issue #6 (S5: PreferenceStore KeyValueStore 주입)
import Testing
@testable import SoloTapDetectorCore

// MARK: - 테스트용 인메모리 KeyValueStore

/// Foundation import 없이 사용 가능한 인메모리 KeyValueStore 구현
final class DictionaryStore: KeyValueStore {
    private var storage: [String: String] = [:]

    func string(forKey key: String) -> String? {
        storage[key]
    }

    func set(_ value: String?, forKey key: String) {
        storage[key] = value
    }
}

// MARK: - PreferenceStoreTests

@Suite struct PreferenceStoreTests {

    // MARK: - Behavior 6: leftCmdSourceID 저장 후 로드

    @Test func leftCmdSourceID_storeAndLoad_roundtrips() {
        let store = PreferenceStore(store: DictionaryStore())

        store.leftCmdSourceID = "com.apple.keylayout.ABC"

        #expect(store.leftCmdSourceID == "com.apple.keylayout.ABC")
    }

    // MARK: - Behavior 7: rightCmdSourceID 저장 후 로드

    @Test func rightCmdSourceID_storeAndLoad_roundtrips() {
        let store = PreferenceStore(store: DictionaryStore())

        store.rightCmdSourceID = "com.apple.inputmethod.Korean.2SetKorean"

        #expect(store.rightCmdSourceID == "com.apple.inputmethod.Korean.2SetKorean")
    }

    // MARK: - Behavior 8: 초기값 nil (저장 안 된 상태)

    @Test func leftCmdSourceID_initialValue_isNil() {
        let store = PreferenceStore(store: DictionaryStore())
        #expect(store.leftCmdSourceID == nil)
    }

    @Test func rightCmdSourceID_initialValue_isNil() {
        let store = PreferenceStore(store: DictionaryStore())
        #expect(store.rightCmdSourceID == nil)
    }

    // MARK: - Behavior 9: 좌·우 설정이 서로 독립적

    @Test func leftAndRight_storeIndependently() {
        let store = PreferenceStore(store: DictionaryStore())

        store.leftCmdSourceID = "com.apple.keylayout.ABC"
        store.rightCmdSourceID = "com.apple.inputmethod.Korean.2SetKorean"

        #expect(store.leftCmdSourceID == "com.apple.keylayout.ABC")
        #expect(store.rightCmdSourceID == "com.apple.inputmethod.Korean.2SetKorean")
    }

    // MARK: - Behavior 10: escForceEnglishEnabled 초기값 false

    @Test func escForceEnglishEnabled_initialValue_isFalse() {
        let store = PreferenceStore(store: DictionaryStore())
        #expect(store.escForceEnglishEnabled == false)
    }

    // MARK: - Behavior 11: escForceEnglishEnabled true 저장/로드 라운드트립

    @Test func escForceEnglishEnabled_storeAndLoad_roundtrips() {
        let store = PreferenceStore(store: DictionaryStore())
        store.escForceEnglishEnabled = true
        #expect(store.escForceEnglishEnabled == true)
    }

    // MARK: - Behavior 12: escForceEnglishEnabled true 후 false 설정 시 false 복귀

    @Test func escForceEnglishEnabled_setFalse_returnsFalse() {
        let store = PreferenceStore(store: DictionaryStore())
        store.escForceEnglishEnabled = true
        store.escForceEnglishEnabled = false
        #expect(store.escForceEnglishEnabled == false)
    }
}
