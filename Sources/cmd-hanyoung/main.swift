// 전역 코드 진입점 — @main 미사용, main.swift 파일명으로 진입점 지정
import Cocoa

// 공유 앱 인스턴스 획득
let app = NSApplication.shared

// 상태바 전용 앱으로 설정 (Dock 아이콘 미표시)
app.setActivationPolicy(.accessory)

// AppDelegate 인스턴스 생성 및 연결
let delegate = AppDelegate()
app.delegate = delegate

// 이벤트 루프 시작
app.run()
