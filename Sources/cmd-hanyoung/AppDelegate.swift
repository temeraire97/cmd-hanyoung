// 앱 델리게이트 — 상태바 아이콘 및 메뉴 구성
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    // 상태바 항목 (앱 생명주기 동안 강한 참조 유지)
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 시스템 상태바에 가변 길이 항목 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 상태바 버튼 아이콘 설정
        if let button = statusItem.button {
            if let globeImage = NSImage(systemSymbolName: "globe", accessibilityDescription: "cmd-hanyoung") {
                // SF Symbol 사용 가능한 경우 globe 아이콘 설정
                button.image = globeImage
            } else {
                // SF Symbol 사용 불가 시 텍스트 폴백
                button.title = "⌘한"
            }
        }

        // 상태바 메뉴 구성
        let menu = NSMenu()

        // 비활성 타이틀 항목 (클릭 불가)
        let titleItem = NSMenuItem(title: "cmd-hanyoung", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // 구분선
        menu.addItem(NSMenuItem.separator())

        // 종료 항목 — target을 self로 명시 (상태바 메뉴는 responder chain 보장 안 됨)
        let quitItem = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // 메뉴 연결
        statusItem.menu = menu
    }

    // 앱 종료
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
