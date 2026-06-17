// 앱 델리게이트 — PreferenceStore, StatusBarController, TapMonitor 조율
import Cocoa
import SoloTapDetectorCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 설정 저장소 (앱 생명주기 동안 강한 참조)
    private let preferenceStore = PreferenceStore()

    // MARK: - 상태바 컨트롤러
    private var statusBarController: StatusBarController!

    // MARK: - CGEventTap 래퍼 — 솔로탭 감지
    private let tapMonitor = TapMonitor()

    // MARK: - 폴백 입력소스 ID 상수

    private static let abcFallback    = "com.apple.keylayout.ABC"
    private static let koreanFallback = "com.apple.inputmethod.Korean.2SetKorean"

    // MARK: - 앱 시작

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 첫 실행 시 기본값 초기화
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

        // TapMonitor 콜백 초기 설정 후 시작
        updateTapMonitorCallbacks()
        tapMonitor.start()
    }

    // MARK: - 기본값 초기화

    /// 첫 실행이거나 저장된 ID가 사용 불가 목록이 된 경우 resolveSourceID로 재설정한다.
    private func initializeDefaultsIfNeeded() {
        let availableIDs = InputSource.enumerate().map(\.id)

        if preferenceStore.leftCmdSourceID == nil {
            preferenceStore.leftCmdSourceID = SourceIDResolver.resolveSourceID(
                stored: nil,
                available: availableIDs,
                fallback: Self.abcFallback
            )
        }

        if preferenceStore.rightCmdSourceID == nil {
            preferenceStore.rightCmdSourceID = SourceIDResolver.resolveSourceID(
                stored: nil,
                available: availableIDs,
                fallback: Self.koreanFallback
            )
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
        tapMonitor.onRight = {
            NSLog("[cmd-hanyoung] right tap → force Korean: %@", rightID)
            InputSource.forceKorean(sourceID: rightID)
        }
    }
}
