// InputSource — TIS(Text Input Sources) 래퍼
// Carbon.TIS API를 사용해 입력소스 열거/조회/선택을 제공한다.
//
// ⚠️ 수동 검증 필요:
//   - TIS API 호출 결과(실제 입력 착지 여부)는 swift test로 검증 불가.
//   - HITL 체크리스트 참고: 좌⌘→영문 착지, 우⌘→한글 실제 입력 착지(아이콘만 아님).
//
// 설계 원칙:
//   - 현재 상태 캐시 금지 — 항상 TIS 직접 조회.
//   - retain/release 정확히 쌍으로 관리.
//   - private API 사용 금지.
import Carbon
import SoloTapDetectorCore

enum InputSource {

    // MARK: - 입력소스 메타데이터 타입

    struct SourceInfo {
        let id: String
        let localizedName: String
        let isASCIICapable: Bool
        let category: String
        /// kTISPropertyInputSourceIsSelectCapable — false이면 IME 상위 컨테이너.
        /// 속성 없으면(nil) true로 처리(안전: 표시 유지).
        let isSelectCapable: Bool
    }

    // MARK: - 열거

    /// 시스템에 등록된 모든 입력소스를 열거한다.
    static func enumerate() -> [SourceInfo] {
        // TISCreateInputSourceList: nil 필터 → 카테고리 제한 없음
        // includeAllInstalled=false → 시스템 설정에 추가된(활성화된) 소스만 반환
        //   (true이면 비활성 설치 소스 포함 전체)
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            return []
        }
        let count = CFArrayGetCount(list)
        var results: [SourceInfo] = []
        results.reserveCapacity(count)

        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(list, i) else { continue }
            // CFArray 내 값은 TISInputSource. retain 없이 직접 캐스트.
            let source = Unmanaged<TISInputSource>.fromOpaque(rawPtr).takeUnretainedValue()

            guard
                let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String?,
                let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String?,
                let catPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                let category = Unmanaged<CFString>.fromOpaque(catPtr).takeUnretainedValue() as String?
            else { continue }

            let isASCIICapable: Bool
            if let asciiPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) {
                isASCIICapable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(asciiPtr).takeUnretainedValue())
            } else {
                isASCIICapable = false
            }

            // kTISPropertyInputSourceIsSelectCapable — nil이면 true(안전 기본값: 표시 유지)
            let isSelectCapable: Bool
            if let selPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) {
                isSelectCapable = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(selPtr).takeUnretainedValue())
            } else {
                isSelectCapable = true
            }

            results.append(SourceInfo(
                id: id,
                localizedName: name,
                isASCIICapable: isASCIICapable,
                category: category,
                isSelectCapable: isSelectCapable
            ))
        }
        return results
    }

    // MARK: - 현재 입력소스 ID

    /// 현재 활성 키보드 입력소스 ID를 반환한다.
    /// takeRetainedValue로 올바르게 소유권을 획득해 ARC에 위임한다.
    static func currentID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    // MARK: - ID로 TISInputSource 클로저 패턴 접근

    /// 입력소스 ID로 TISInputSource를 찾아 클로저 내에서 사용한다.
    /// list를 클로저 범위 안에서만 유지함으로써 TISInputSource dangling 위험을 방지한다.
    /// - Parameters:
    ///   - id: 탐색할 입력소스 ID
    ///   - body: 소스를 인자로 받는 클로저 (list 수명 내에서만 호출됨)
    private static func withInputSource(id: String, _ body: (TISInputSource) -> Void) {
        // includeAllInstalled=false → 활성화된 소스만 반환 (비활성 포함 전체는 true)
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            return
        }
        let count = CFArrayGetCount(list)
        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(list, i) else { continue }
            let source = Unmanaged<TISInputSource>.fromOpaque(rawPtr).takeUnretainedValue()
            guard
                let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                (Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String) == id
            else { continue }
            // list가 살아있는 스코프 안에서 body 호출 — dangling 없음
            body(source)
            return
        }
    }

    // MARK: - 선택 (idempotent)

    /// 입력소스를 선택한다. 이미 현재 소스이면 무동작(idempotent).
    static func select(id: String) {
        guard InputSourceClassifier.needsSwitch(targetID: id, currentID: currentID()) else {
            return // 이미 현재 소스 — 무동작
        }
        var selected = false
        withInputSource(id: id) { source in
            TISSelectInputSource(source)
            selected = true
        }
        if !selected {
            NSLog("[cmd-hanyoung] InputSource.select: ID 없음 — %@", id)
        }
    }

    // MARK: - 영문 강제 전환

    /// 비-CJKV(ASCII) 입력소스를 직접 선택한다.
    /// 영문 소스는 TISSelectInputSource 직접 호출로 충분 — 버그 없음.
    ///
    /// - Parameter sourceID: 대상 영문 입력소스 ID (예: "com.apple.keylayout.ABC")
    static func forceEnglish(sourceID: String) {
        select(id: sourceID)
    }

    // MARK: - 한글 강제 전환 (CJKV 우회)

    /// CJKV 입력소스를 선택한다.
    /// CJKV select 버그(메뉴바 아이콘만 바뀌고 실제 입력 언어 미변경)를 우회한다.
    ///
    /// 전략:
    ///   1. TISSelectInputSource(abc) → TISSelectInputSource(kor) 순서로 known-base 경유 선택.
    ///   2. CompositorNudge.shared.nudge()로 CJKV compositor 세션 경계를 강제 발생시켜
    ///      IMKInputController가 한글 모드로 재초기화되도록 한다.
    ///
    /// ⚠️ 메인 큐에서만 호출해야 한다 (AppKit 윈도우 조작 포함).
    ///
    /// - Parameters:
    ///   - sourceID: 대상 한글 입력소스 ID (예: "com.apple.inputmethod.Korean.2SetKorean")
    ///   - englishID: bounce 1단계에 사용할 영문 입력소스 ID (예: "com.apple.keylayout.ABC")
    /// - Returns: true이면 전환 성공(또는 이미 목표 소스), false이면 목표 소스를 찾지 못해 실패.
    @discardableResult
    static func forceKorean(sourceID: String, englishID: String) -> Bool {
        let switched = selectKoreanWorkaround(targetID: sourceID, englishID: englishID)
        // switched == nil → 소스 없음(실패)
        // switched == false → 이미 목표 소스(성공: no-op)
        // switched == true → 실제 전환 수행(성공: nudge 필요)
        guard let didSwitch = switched else {
            return false
        }
        if didSwitch {
            // 실제로 전환이 발생한 경우에만 nudge — 이미 한글이면 compositor는 정상 상태.
            // nudge()는 비동기(asyncAfter)이므로 이벤트탭 스레드를 블로킹하지 않는다.
            CompositorNudge.shared.nudge()
        }
        return true
    }

    // MARK: - CJKV 선택 우회 (focus-nudge 기법)

    /// CJKV select 버그 우회 구현.
    ///
    /// 배경:
    ///   macOS에서 CJKV IME를 TISSelectInputSource로 직접 선택하면
    ///   메뉴바 아이콘은 바뀌지만 실제 compositor가 전환되지 않는 버그가 있다.
    ///   macOS Tahoe에서 기존 double-bounce(d 단계 재선택) 기법이 더 이상 신뢰성 없음.
    ///
    /// 우회 전략 (abc → kor + focus nudge):
    ///   a. 이미 목표 소스이면 return (idempotent) — nudge도 건너뜀.
    ///   b. 영문(비-CJKV) 소스로 먼저 전환해 known-base 상태로 정착시킨다.
    ///      englishID 소스가 없으면 bounce 단계를 건너뛰고 직접 선택 시도.
    ///   c. 목표 한글 소스를 TISSelectInputSource로 선택한다.
    ///   d. (제거됨) 이전 double-select bounce → CompositorNudge.shared.nudge()로 대체.
    ///      forceKorean()에서 이 함수 반환 후 nudge()를 호출한다.
    ///
    /// 불확실성:
    ///   - nudge 효과(makeKeyAndOrderFront로 IMKInputController flush)는 HITL 수동 검증 필수.
    ///   - 실제 착지 여부는 HITL 체크리스트 참고.
    ///
    /// - Parameters:
    ///   - targetID: 전환 목표 CJKV 입력소스 ID
    ///   - englishID: 1단계에 사용할 영문(비-CJKV) 입력소스 ID
    /// - Returns: true이면 실제로 입력소스 전환을 수행했음(nudge 필요),
    ///            false이면 이미 목표 소스(nudge 불필요),
    ///            nil이면 목표 소스를 찾지 못해 전환 실패.
    private static func selectKoreanWorkaround(targetID: String, englishID: String) -> Bool? {
        // a. 이미 목표 소스 — 무동작. compositor는 이미 한글 상태이므로 nudge 불필요.
        guard InputSourceClassifier.needsSwitch(targetID: targetID, currentID: currentID()) else {
            return false
        }

        // b. 영문(비-CJKV) 소스로 먼저 전환 — known-base 상태로 정착
        //    englishID 소스를 찾지 못하면 이 단계 생략하고 직접 선택 시도
        withInputSource(id: englishID) { abcSource in
            TISSelectInputSource(abcSource)
        }

        // c. 목표 한글 소스 선택
        var korFound = false
        withInputSource(id: targetID) { korSource in
            TISSelectInputSource(korSource)
            korFound = true
        }
        guard korFound else {
            NSLog("[cmd-hanyoung] InputSource.selectKoreanWorkaround: 한글 소스 ID 없음 — %@", targetID)
            return nil
        }

        // d. (제거) 동일 소스 재선택 bounce — CompositorNudge.shared.nudge()로 대체.
        //    focus nudge가 IMKInputController 세션 경계를 올바르게 발생시키므로 불필요.
        return true
    }
}
