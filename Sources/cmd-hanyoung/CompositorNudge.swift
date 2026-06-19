// CompositorNudge — CJKV compositor 세션 경계 강제 발생 (AppKit 의존)
// Carbon/TIS 레이어(InputSource.swift)에서 분리된 AppKit 전용 모듈.
//
// ⚠️ 메인 큐 전용. TapMonitor → DispatchQueue.main.async → forceKorean 경로로만 호출됨.
//
// ⚠️ HITL 확인 필요:
//   - nudge 창이 settle 기간 동안 포커스를 획득하는 동안 타이핑하면 keystrokes가 드롭됨.
//   - previousApp?.activate 복귀 후 삽입점이 올바른 텍스트 필드로 돌아가는지 확인.
import AppKit

/// CJKV compositor(IMKInputController)가 TISSelectInputSource 이후에도 이전 세션 상태를
/// 유지하는 문제를 해결하기 위해 AppKit 포커스 변경 이벤트를 인위적으로 발생시킨다.
///
/// 동작 원리:
///   1. 현재 포그라운드 앱을 먼저 기억한다(previousApp 캡처는 반드시 activate 이전).
///   2. `.titled` styleMask NSWindow를 makeKeyAndOrderFront해 창이 키를 획득하도록 함.
///      이 순간 포그라운드 앱의 IMKInputController가 세션 종료 알림을 받는다.
///      (.borderless 창은 key 윈도우가 될 수 없으므로 반드시 .titled 사용)
///   3. settle 후 orderOut + 이전 앱 activate 복귀.
final class CompositorNudge {

    static let shared = CompositorNudge()

    private init() {}

    /// settle 기간: Tahoe에서 경험적으로 안정된 값 150ms. HITL 결과에 따라 100–150ms 범위에서 조정.
    private let settleDuration: TimeInterval = 0.15

    /// 인플라이트 nudge 윈도우. nil이면 nudge 대기 없음.
    /// 디바운스 가드: non-nil이면 새 nudge 생성을 건너뜀(첫 번째로 충분).
    private var nudgeWindow: NSWindow?

    /// TISSelectInputSource(kor) 호출 직후 이 메서드를 호출한다.
    /// 메인 큐에서만 호출해야 한다.
    func nudge() {
        // 디바운스: 이미 nudge 진행 중이면 추가 생성 불필요.
        // TISSelectInputSource 호출은 이미 완료되었으므로 소스 전환 자체는 정상.
        guard nudgeWindow == nil else { return }

        // previousApp 캡처는 반드시 NSApp.activate / makeKeyAndOrderFront 이전에 수행.
        // activate 이후 캡처하면 frontmostApplication이 자신(에이전트)으로 바뀌어 복귀 대상을 잃는다.
        let previousApp = NSWorkspace.shared.frontmostApplication

        // .titled styleMask: key 윈도우가 될 수 있는 최소 조건.
        // .borderless 창은 canBecomeKey == false이므로 compositor 세션 경계를 유발하지 못한다.
        // 크기 3×3px — 화면에 거의 보이지 않음. 위치: 메인 스크린 우하단 모서리 근처.
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let margin: CGFloat = 8
        let size: CGFloat = 3
        let origin = CGPoint(
            x: screenFrame.maxX - size - margin,
            y: screenFrame.minY + margin
        )
        let w = NSWindow(
            contentRect: NSRect(origin: origin, size: CGSize(width: size, height: size)),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        // screenSaver 레벨: 일반 창 및 풀스크린 앱 위에서 키를 획득할 수 있도록
        w.level = .screenSaver
        // 스페이스 전환/풀스크린 앱에서도 동작하도록
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // ARC로 직접 수명 제어 — closed 시 자동 해제 비활성화
        w.isReleasedWhenClosed = false

        self.nudgeWindow = w

        // 창이 키를 획득 → 포그라운드 앱의 IMKInputController가 세션 종료 알림 수신
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // settle 후 창 제거 및 포그라운드 앱 복귀
        // asyncAfter이므로 메인 런루프를 블로킹하지 않는다.
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDuration) { [weak self] in
            guard let self = self else { return }
            self.nudgeWindow?.orderOut(nil)
            self.nudgeWindow = nil
            // 원래 포그라운드 앱으로 포커스 복귀
            previousApp?.activate(options: [])
        }
    }
}
