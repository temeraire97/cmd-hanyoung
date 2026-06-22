// 앱 델리게이트 — PreferenceStore, StatusBarController, TapMonitor 조율
import Cocoa
import ApplicationServices
import SoloTapDetectorCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 설정 저장소 (앱 생명주기 동안 강한 참조)
    private let preferenceStore = PreferenceStore()

    // MARK: - 상태바 컨트롤러
    private var statusBarController: StatusBarController!

    // MARK: - CGEventTap 래퍼 — 솔로탭 감지
    private let tapMonitor = TapMonitor()

    // MARK: - 접근성 권한 재확인 타이머
    private var accessibilityTimer: Timer?

    // MARK: - 슬립/웨이크 복구 옵저버
    private var wakeObserver: NSObjectProtocol?

    // MARK: - 폴백 입력소스 ID 상수

    private static let abcFallback    = "com.apple.keylayout.ABC"
    private static let koreanFallback = "com.apple.inputmethod.Korean.2SetKorean"

    // MARK: - 앱 시작

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ── 단일 인스턴스 보장 ──────────────────────────────────────────────
        // 자신의 bundle ID가 없으면(언번들 swift run 등) 검사 생략
        if let myBundleID = Bundle.main.bundleIdentifier {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let duplicates = NSWorkspace.shared.runningApplications.filter {
                $0.bundleIdentifier == myBundleID && $0.processIdentifier != myPID
            }
            if !duplicates.isEmpty {
                for app in duplicates {
                    NSLog("[cmd-hanyoung] 기존 인스턴스 종료 요청 (pid=%d)", app.processIdentifier)
                    app.terminate()
                }
                // 2초 후에도 살아있으면 강제 종료
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    for app in duplicates where app.isTerminated == false {
                        NSLog("[cmd-hanyoung] 기존 인스턴스 강제 종료 (pid=%d)", app.processIdentifier)
                        app.forceTerminate()
                    }
                }
            }
        }
        // ── 단일 인스턴스 보장 끝 ──────────────────────────────────────────

        // 첫 실행이거나 저장 ID가 현재 시스템에 없으면 재설정
        initializeDefaultsIfNeeded()

        // 상태바 컨트롤러 생성 및 설정
        statusBarController = StatusBarController(preferenceStore: preferenceStore)
        statusBarController.onLeftCmdSourceChanged = { [weak self] _ in
            self?.updateTapMonitorCallbacks()
        }
        statusBarController.onRightCmdSourceChanged = { [weak self] _ in
            self?.updateTapMonitorCallbacks()
        }
        statusBarController.setup()

        // TapMonitor 콜백 초기 설정
        updateTapMonitorCallbacks()

        // 접근성 권한 확인 후 TapMonitor 시작
        checkAccessibilityAndStart(promptIfNeeded: true)

        // 슬립 → 웨이크 시 CGEventTap 복구 (NFR-3)
        registerWakeObserver()
    }

    // MARK: - 앱 종료 시 정리

    func applicationWillTerminate(_ notification: Notification) {
        tapMonitor.stop()
        stopAccessibilityTimer()
        removeWakeObserver()
    }

    // MARK: - 앱 활성화 시 재확인

    func applicationDidBecomeActive(_ notification: Notification) {
        // 이미 신뢰 상태이면 무동작
        guard !AXIsProcessTrusted() else { return }
        checkAccessibilityAndStart(promptIfNeeded: false)
    }

    // MARK: - 접근성 권한 확인 및 TapMonitor 시작

    /// 접근성 권한을 확인하고, 신뢰 여부에 따라 TapMonitor 시작 및 경고 갱신.
    /// - Parameter promptIfNeeded: 미신뢰 시 시스템 프롬프트를 표시할지 여부
    private func checkAccessibilityAndStart(promptIfNeeded: Bool) {
        let trusted: Bool
        if promptIfNeeded && !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }

        statusBarController.updateAccessibilityState(trusted: trusted)

        if trusted {
            // 권한 확보 — 타이머 중단, TapMonitor 시작(이미 실행 중이면 무동작)
            stopAccessibilityTimer()
            tapMonitor.start()
        } else {
            // 권한 미확보 — TapMonitor를 시작하지 않고 주기적으로 재확인
            startAccessibilityTimerIfNeeded()
        }
    }

    // MARK: - 접근성 재확인 타이머

    private func startAccessibilityTimerIfNeeded() {
        guard accessibilityTimer == nil else { return }
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                self.stopAccessibilityTimer()
                self.statusBarController.updateAccessibilityState(trusted: true)
                self.tapMonitor.start()
            }
        }
    }

    private func stopAccessibilityTimer() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    // MARK: - 기본값 초기화

    /// 첫 실행이거나 저장된 ID가 현재 시스템의 사용 가능 목록에 없는 경우
    /// resolveSourceID로 재설정해 무효 ID 잔존을 방지한다.
    /// availableIDs는 선택 가능한 키보드 소스만 포함 — 컨테이너 ID가 저장돼 있으면 재설정되도록.
    private func initializeDefaultsIfNeeded() {
        let availableIDs = InputSource.enumerate()
            .filter { InputSourceClassifier.isSelectableKeyboardSource(
                isSelectCapable: $0.isSelectCapable,
                category: $0.category
            ) }
            .map(\.id)

        let storedLeft = preferenceStore.leftCmdSourceID
        if storedLeft == nil || !availableIDs.contains(storedLeft!) {
            preferenceStore.leftCmdSourceID = SourceIDResolver.resolveSourceID(
                stored: nil,
                available: availableIDs,
                fallback: Self.abcFallback
            )
        }

        let storedRight = preferenceStore.rightCmdSourceID
        if storedRight == nil || !availableIDs.contains(storedRight!) {
            preferenceStore.rightCmdSourceID = SourceIDResolver.resolveSourceID(
                stored: nil,
                available: availableIDs,
                fallback: Self.koreanFallback
            )
        }
    }

    // MARK: - 슬립/웨이크 복구

    private func registerWakeObserver() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            NSLog("[cmd-hanyoung] 시스템 웨이크 감지 — CGEventTap 재시작")
            self.tapMonitor.restart()
        }
    }

    private func removeWakeObserver() {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }

    // MARK: - TapMonitor 콜백 갱신

    private func updateTapMonitorCallbacks() {
        let leftID  = preferenceStore.leftCmdSourceID  ?? Self.abcFallback
        let rightID = preferenceStore.rightCmdSourceID ?? Self.koreanFallback

        tapMonitor.onLeft = {
            NSLog("[cmd-hanyoung] left tap → force English: %@", leftID)
            InputSource.forceEnglish(sourceID: leftID)
        }
        tapMonitor.onRight = { [weak self] in
            NSLog("[cmd-hanyoung] right tap → force Korean: %@", rightID)
            let ok = InputSource.forceKorean(sourceID: rightID, englishID: leftID)
            self?.statusBarController.updateKoreanSwitchState(succeeded: ok)
        }
        tapMonitor.onEscape = { [weak self] in
            guard self?.preferenceStore.escForceEnglishEnabled == true else { return }
            NSLog("[cmd-hanyoung] ESC → force English: %@", leftID)
            InputSource.forceEnglish(sourceID: leftID)
        }
    }
}
