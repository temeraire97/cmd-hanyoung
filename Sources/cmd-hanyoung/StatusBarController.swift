// StatusBarController — 메뉴바 아이콘 + 입력소스 선택 메뉴 관리
// NSStatusItem, NSMenu 소유. AppDelegate가 생성·소유한다.
import Cocoa
import ServiceManagement
import SoloTapDetectorCore

/// 메뉴바 상태 아이콘과 입력소스 선택 메뉴를 담당하는 컨트롤러
final class StatusBarController {

    // MARK: - TIS 알림 이름

    private static let tisNotificationName = Notification.Name(
        "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
    )

    // MARK: - 의존성

    private let preferenceStore: PreferenceStore

    // MARK: - 콜백 (AppDelegate로 설정 변경 보고)

    /// 좌⌘ 소스 변경 시 호출 — 새 sourceID 전달
    var onLeftCmdSourceChanged: ((String) -> Void)?

    /// 우⌘ 소스 변경 시 호출 — 새 sourceID 전달
    var onRightCmdSourceChanged: ((String) -> Void)?

    // MARK: - UI 컴포넌트

    private var statusItem: NSStatusItem!

    // MARK: - 접근성 경고 상태

    private var isAccessibilityTrusted: Bool = true

    // MARK: - Init

    /// - Parameter preferenceStore: 설정 읽기·쓰기에 사용할 저장소
    init(preferenceStore: PreferenceStore) {
        self.preferenceStore = preferenceStore
    }

    // MARK: - 설정 (applicationDidFinishLaunching에서 호출)

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 정적 globe 아이콘 (Phase 2에서 동적 A/한 표시 예정)
        if let button = statusItem.button {
            if let globeImage = NSImage(systemSymbolName: "globe", accessibilityDescription: "cmd-hanyoung") {
                button.image = globeImage
            } else {
                button.title = "⌘한"
            }
        }

        buildMenu()
        observeTISChanges()
    }

    // MARK: - 접근성 상태 갱신 (공개 API)

    /// 접근성 권한 상태를 갱신하고 메뉴 경고 항목을 표시/숨긴다.
    /// 재호출 시 idempotent — 중복 항목 추가 없음.
    func updateAccessibilityState(trusted: Bool) {
        isAccessibilityTrusted = trusted
        buildMenu()
    }

    // MARK: - 메뉴 구성

    private func buildMenu() {
        let menu = NSMenu()

        // 미신뢰 시 경고 항목을 최상단에 추가
        if !isAccessibilityTrusted {
            let warningItem = NSMenuItem(
                title: "⚠️ 손쉬운 사용 권한 필요 — 클릭하여 설정 열기",
                action: #selector(openAccessibilityPreferences),
                keyEquivalent: ""
            )
            warningItem.target = self
            menu.addItem(warningItem)
            menu.addItem(NSMenuItem.separator())
        }

        // 좌⌘ 서브메뉴
        let leftItem = NSMenuItem(title: "좌⌘ →", action: nil, keyEquivalent: "")
        leftItem.submenu = makeSourceSubmenu(
            currentID: preferenceStore.leftCmdSourceID,
            action: #selector(leftSourceSelected(_:))
        )
        menu.addItem(leftItem)

        // 우⌘ 서브메뉴
        let rightItem = NSMenuItem(title: "우⌘ →", action: nil, keyEquivalent: "")
        rightItem.submenu = makeSourceSubmenu(
            currentID: preferenceStore.rightCmdSourceID,
            action: #selector(rightSourceSelected(_:))
        )
        menu.addItem(rightItem)

        menu.addItem(NSMenuItem.separator())

        // 로그인 시 자동 실행 토글
        let loginItem = NSMenuItem(
            title: "로그인 시 자동 실행",
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        if #available(macOS 13, *) {
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // 종료
        let quitItem = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// 입력소스 목록 서브메뉴 생성
    private func makeSourceSubmenu(currentID: String?, action: Selector) -> NSMenu {
        let submenu = NSMenu()
        let sources = InputSource.enumerate()

        for source in sources {
            let item = NSMenuItem(title: source.localizedName, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = source.id
            item.state = (source.id == currentID) ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    // MARK: - 메뉴 액션

    @objc private func leftSourceSelected(_ sender: NSMenuItem) {
        guard let sourceID = sender.representedObject as? String else { return }
        preferenceStore.leftCmdSourceID = sourceID
        onLeftCmdSourceChanged?(sourceID)
        refreshMenu()
    }

    @objc private func rightSourceSelected(_ sender: NSMenuItem) {
        guard let sourceID = sender.representedObject as? String else { return }
        preferenceStore.rightCmdSourceID = sourceID
        onRightCmdSourceChanged?(sourceID)
        refreshMenu()
    }

    @objc private func toggleLoginItem() {
        if #available(macOS 13, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    try service.register()
                }
            } catch {
                NSLog("[cmd-hanyoung] SMAppService toggle 실패: %@", error.localizedDescription)
            }
        }
        buildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func openAccessibilityPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 메뉴 갱신

    /// 현재 설정을 반영해 체크표시를 갱신한다.
    private func refreshMenu() {
        buildMenu()
    }

    // MARK: - TIS 알림 옵저버

    private func observeTISChanges() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: Self.tisNotificationName,
            object: nil
        )
    }

    @objc private func inputSourceChanged() {
        refreshMenu()
    }

    // MARK: - 정리

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
