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
}
