// SoloTapDetector — 순수 로직, CGEventTap 의존 없음
// 솔로탭 판정: modifier 단독 다운→업(임계내, 방해 없음) → SoloTap 반환
import Foundation

/// 감지된 솔로탭 방향
public enum SoloTap: Equatable {
    case left
    case right
}

/// CGEvent 없이 이벤트 서술자만 받아 솔로탭 판정
public final class SoloTapDetector {

    // MARK: - 입력 추상화

    /// modifier 키 이벤트 서술자
    public struct ModifierEvent {
        public let keyCode: UInt16
        public let isDown: Bool
        public let timestamp: TimeInterval

        public init(keyCode: UInt16, isDown: Bool, timestamp: TimeInterval) {
            self.keyCode = keyCode
            self.isDown = isDown
            self.timestamp = timestamp
        }
    }

    /// 그 외 입력(keyDown / mouseDown) 서술자
    public struct OtherInputEvent {
        public let timestamp: TimeInterval

        public init(timestamp: TimeInterval) {
            self.timestamp = timestamp
        }
    }

    // MARK: - 상태

    private enum State {
        case idle
        case watching(keyCode: UInt16, downAt: TimeInterval)
        case canceled
    }

    // MARK: - 설정

    /// 솔로탭 인정 최대 누름 시간 (기본 0.3s)
    public let holdThreshold: TimeInterval

    // MARK: - 내부 상태

    private var state: State = .idle

    // MARK: - 좌⌘/우⌘ keyCode 상수

    private static let leftCmdKeyCode: UInt16  = 55
    private static let rightCmdKeyCode: UInt16 = 54

    // MARK: - Init

    public init(holdThreshold: TimeInterval = 0.3) {
        self.holdThreshold = holdThreshold
    }

    // MARK: - Public API

    /// modifier 이벤트를 처리하고, 솔로탭이 완성되면 SoloTap 반환
    @discardableResult
    public func handle(modifier event: ModifierEvent) -> SoloTap? {
        let isCmdKey = event.keyCode == Self.leftCmdKeyCode
                    || event.keyCode == Self.rightCmdKeyCode

        if event.isDown {
            // 다운: 감시 시작(cmd) 또는 다른 modifier 끼어들어 취소
            if isCmdKey {
                state = .watching(keyCode: event.keyCode, downAt: event.timestamp)
            } else {
                // 다른 modifier 다운 → 현재 후보 취소
                state = .canceled
            }
            return nil
        } else {
            // 업: 감시 중인 키가 임계내에 떼졌는지 판정
            guard case .watching(let watchedKeyCode, let downAt) = state else {
                state = .idle
                return nil
            }

            // 다른 키의 업 이벤트는 무시하지 않고 취소 처리
            guard event.keyCode == watchedKeyCode else {
                state = .canceled
                return nil
            }

            let elapsed = event.timestamp - downAt
            state = .idle

            guard elapsed <= holdThreshold else {
                return nil // 홀드 — 임계 초과
            }

            // 솔로탭 확정
            return event.keyCode == Self.leftCmdKeyCode ? .left : .right
        }
    }

    /// 그 외 입력(keyDown/mouseDown) — 현재 후보 취소
    public func handleOtherInput(_ event: OtherInputEvent) {
        state = .canceled
    }
}
