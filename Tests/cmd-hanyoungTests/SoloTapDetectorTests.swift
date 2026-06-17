// SoloTapDetector 행동 테스트 — issue #3 (S2: TapMonitor 솔로탭 감지)
import Testing
@testable import SoloTapDetectorCore

@Suite struct SoloTapDetectorTests {

    // MARK: - Behavior 1: 좌⌘ 단독 다운→임계내 업 → .left

    @Test func leftCmd_downThenUpWithinThreshold_returnsLeft() {
        let detector = SoloTapDetector()
        // 좌⌘ keyCode = 55
        let down = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true, timestamp: 0.0)
        let up   = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.2)

        let _ = detector.handle(modifier: down)
        let result = detector.handle(modifier: up)

        #expect(result == .left)
    }

    // MARK: - Behavior 2: 우⌘ 단독 → .right

    @Test func rightCmd_downThenUpWithinThreshold_returnsRight() {
        let detector = SoloTapDetector()
        // 우⌘ keyCode = 54
        let down = SoloTapDetector.ModifierEvent(keyCode: 54, isDown: true, timestamp: 0.0)
        let up   = SoloTapDetector.ModifierEvent(keyCode: 54, isDown: false, timestamp: 0.15)

        let _ = detector.handle(modifier: down)
        let result = detector.handle(modifier: up)

        #expect(result == .right)
    }
}
