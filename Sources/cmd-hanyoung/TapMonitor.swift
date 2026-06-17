// TapMonitor — CGEventTap 래퍼
// SoloTapDetector에 CGEvent를 먹이고, 솔로탭 감지 시 콜백 호출
import Cocoa
import SoloTapDetectorCore

final class TapMonitor {

    // MARK: - 콜백

    var onLeft:  (() -> Void)?
    var onRight: (() -> Void)?

    // MARK: - 내부

    private let detector = SoloTapDetector()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - 공개 API

    func start() {
        guard eventTap == nil else { return }

        // flagsChanged + keyDown + 모든 mouseDown 마스크
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue)   |
            (1 << CGEventType.keyDown.rawValue)        |
            (1 << CGEventType.leftMouseDown.rawValue)  |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        // refcon: Unmanaged passUnretained — retain cycle 없음
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<TapMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.processEvent(type: type, event: event)
                // Command 비소비 — 항상 원본 이벤트 패스스루
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("[cmd-hanyoung] CGEvent.tapCreate 실패 — 접근성 권한 필요")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - 이벤트 처리

    private func processEvent(type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            // modifier 키 이벤트 → SoloTapDetector에 전달
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            // flagsChanged에서 isDown 판정: 해당 modifier flag가 현재 flags에 포함되는지
            let flags = event.flags
            let isDown = isModifierDown(keyCode: keyCode, flags: flags)
            let evt = SoloTapDetector.ModifierEvent(
                keyCode: keyCode,
                isDown: isDown,
                timestamp: event.timestamp.toTimeInterval()
            )
            if let tap = detector.handle(modifier: evt) {
                switch tap {
                case .left:  onLeft?()
                case .right: onRight?()
                }
            }

        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // 그 외 입력 → 현재 후보 취소
            let evt = SoloTapDetector.OtherInputEvent(timestamp: event.timestamp.toTimeInterval())
            detector.handleOtherInput(evt)

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // tap 비활성화 수신 시 즉시 재활성화
            if let tap = eventTap {
                NSLog("[cmd-hanyoung] EventTap 비활성화 감지 — 재활성화")
                CGEvent.tapEnable(tap: tap, enable: true)
            }

        default:
            break
        }
    }

    // MARK: - 헬퍼

    /// flagsChanged 이벤트에서 해당 keyCode의 modifier가 눌렸는지 판정
    private func isModifierDown(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch keyCode {
        case 55, 54: // 좌⌘, 우⌘
            return flags.contains(.maskCommand)
        case 56, 60: // 좌Shift, 우Shift
            return flags.contains(.maskShift)
        case 58, 61: // 좌Option, 우Option
            return flags.contains(.maskAlternate)
        case 59, 62: // 좌Control, 우Control
            return flags.contains(.maskControl)
        default:
            return false
        }
    }
}

// MARK: - UInt64(Mach timestamp) → TimeInterval 변환

private extension UInt64 {
    func toTimeInterval() -> TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanos = self * UInt64(info.numer) / UInt64(info.denom)
        return TimeInterval(nanos) / 1_000_000_000
    }
}
