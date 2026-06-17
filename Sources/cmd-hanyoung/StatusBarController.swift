// StatusBarController — 메뉴바 아이콘 + 입력소스 선택 메뉴 관리
// NSStatusItem, NSMenu 소유. AppDelegate가 생성·소유한다.
import Cocoa
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

    // MARK: - 메뉴 구성

    private func buildMenu() {
        let menu = NSMenu()

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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
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
