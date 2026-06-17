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

    // MARK: - Behavior 3: ⌘ 다운 후 다른 키 입력 끼어듦 → nil(취소)

    @Test func leftCmd_otherKeyInterrupt_returnsNil() {
        let detector = SoloTapDetector()
        let cmdDown = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true, timestamp: 0.0)
        let otherInput = SoloTapDetector.OtherInputEvent(timestamp: 0.1)
        let cmdUp = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.2)

        let _ = detector.handle(modifier: cmdDown)
        detector.handleOtherInput(otherInput)
        let result = detector.handle(modifier: cmdUp)

        #expect(result == nil)
    }

    // MARK: - Behavior 4: ⌘ 다운 후 마우스다운 → nil

    @Test func leftCmd_mouseDownInterrupt_returnsNil() {
        let detector = SoloTapDetector()
        let cmdDown   = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true, timestamp: 0.0)
        let mouseDown = SoloTapDetector.OtherInputEvent(timestamp: 0.05)
        let cmdUp     = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.1)

        let _ = detector.handle(modifier: cmdDown)
        detector.handleOtherInput(mouseDown)
        let result = detector.handle(modifier: cmdUp)

        #expect(result == nil)
    }

    // MARK: - Behavior 5: ⌘ 다운 후 다른 modifier 끼어듦 → nil

    @Test func leftCmd_otherModifierInterrupt_returnsNil() {
        let detector = SoloTapDetector()
        // 좌⌘ 누름
        let cmdDown   = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true, timestamp: 0.0)
        // Shift(keyCode 56) 다운 — 다른 modifier 끼어듦
        let shiftDown = SoloTapDetector.ModifierEvent(keyCode: 56, isDown: true, timestamp: 0.1)
        let cmdUp     = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.2)

        let _ = detector.handle(modifier: cmdDown)
        let _ = detector.handle(modifier: shiftDown)
        let result = detector.handle(modifier: cmdUp)

        #expect(result == nil)
    }

    // MARK: - Behavior 6: 임계시간 초과 후 업 → nil(홀드)

    @Test func leftCmd_upAfterThreshold_returnsNil() {
        // 임계 0.3s 주입
        let detector = SoloTapDetector(holdThreshold: 0.3)
        let cmdDown = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true, timestamp: 0.0)
        // 0.31s 이후 업 — 임계(0.3s) 초과
        let cmdUp   = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.31)

        let _ = detector.handle(modifier: cmdDown)
        let result = detector.handle(modifier: cmdUp)

        #expect(result == nil)
    }

    // MARK: - Behavior 7: 연속 두 번 솔로탭 → 각각 .left 반환

    @Test func leftCmd_twoConsecutiveSoloTaps_eachReturnsLeft() {
        let detector = SoloTapDetector()

        // 첫 번째 탭
        let down1 = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true,  timestamp: 0.0)
        let up1   = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.1)
        // 두 번째 탭
        let down2 = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: true,  timestamp: 0.5)
        let up2   = SoloTapDetector.ModifierEvent(keyCode: 55, isDown: false, timestamp: 0.6)

        let _ = detector.handle(modifier: down1)
        let result1 = detector.handle(modifier: up1)

        let _ = detector.handle(modifier: down2)
        let result2 = detector.handle(modifier: up2)

        #expect(result1 == .left)
        #expect(result2 == .left)
    }
}
