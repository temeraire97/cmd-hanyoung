// InputSourceClassifier 행동 테스트 — issue #4 (S3: InputSource 전환 분류 로직)
import Testing
@testable import SoloTapDetectorCore

@Suite struct InputSourceClassifierTests {

    // MARK: - Behavior 1: isASCIICapable == true → .english

    @Test func asciiCapable_classifiesAsEnglish() {
        let result = InputSourceClassifier.classify(
            category: InputSourceClassifier.categoryKeyboardInputSource,
            isASCIICapable: true
        )
        #expect(result == .english)
    }

    // MARK: - Behavior 2: isASCIICapable == false + keyboard input method category → .cjkv

    @Test func notASCIICapable_keyboardInputMethodCategory_classifiesAsCJKV() {
        let result = InputSourceClassifier.classify(
            category: InputSourceClassifier.categoryKeyboardInputSource,
            isASCIICapable: false
        )
        #expect(result == .cjkv)
    }

    // MARK: - Behavior 5: category nil → .other

    @Test func nilCategory_classifiesAsOther() {
        let result = InputSourceClassifier.classify(category: nil, isASCIICapable: false)
        #expect(result == .other)
    }

    // MARK: - Behavior 3: needsSwitch — currentID == targetID → false (전환 불필요)

    @Test func needsSwitch_sameID_returnsFalse() {
        let sameID = "com.apple.keylayout.ABC"
        let result = InputSourceClassifier.needsSwitch(targetID: sameID, currentID: sameID)
        #expect(result == false)
    }

    // MARK: - Behavior 4: needsSwitch — currentID != targetID → true (전환 필요)

    @Test func needsSwitch_differentID_returnsTrue() {
        let result = InputSourceClassifier.needsSwitch(
            targetID: "com.apple.inputmethod.Korean.2SetKorean",
            currentID: "com.apple.keylayout.ABC"
        )
        #expect(result == true)
    }

    // MARK: - Behavior 6: needsSwitch — currentID nil → true (현재 소스 불명 → 전환 시도)

    @Test func needsSwitch_nilCurrentID_returnsTrue() {
        let result = InputSourceClassifier.needsSwitch(
            targetID: "com.apple.keylayout.ABC",
            currentID: nil
        )
        #expect(result == true)
    }
}
