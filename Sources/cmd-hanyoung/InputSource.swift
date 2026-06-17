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

            results.append(SourceInfo(
                id: id,
                localizedName: name,
                isASCIICapable: isASCIICapable,
                category: category
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
    /// - Parameters:
    ///   - sourceID: 대상 한글 입력소스 ID (예: "com.apple.inputmethod.Korean.2SetKorean")
    ///   - englishID: bounce 1단계에 사용할 영문 입력소스 ID (예: "com.apple.keylayout.ABC")
    static func forceKorean(sourceID: String, englishID: String) {
        selectKoreanWorkaround(targetID: sourceID, englishID: englishID)
    }

    // MARK: - CJKV 선택 우회 (bounce 기법)

    /// CJKV select 버그 우회 구현.
    ///
    /// 배경:
    ///   macOS에서 CJKV IME를 TISSelectInputSource로 직접 선택하면
    ///   메뉴바 아이콘은 바뀌지만 실제 compositor가 전환되지 않는 버그가 있다.
    ///
    /// 우회 전략 (bounce):
    ///   a. 이미 목표 소스이면 return (idempotent).
    ///   b. 영문(비-CJKV) 소스로 먼저 전환해 known-base 상태로 정착시킨다.
    ///      englishID 소스가 없으면 bounce 단계를 건너뛰고 직접 선택 시도.
    ///   c. 목표 한글 소스를 TISSelectInputSource로 선택한다.
    ///   d. 다시 한 번 재선택해 compositor 강제 정착("bounce").
    ///
    /// 불확실성:
    ///   - 이 기법이 macOS 버전/하드웨어 조합 전체에서 동작하는지 미검증.
    ///   - 실제 착지 여부는 HITL 수동 검증 필수.
    ///
    /// 향후 개선 여지:
    ///   - Kawa 앱의 '다음 소스' 반복 폴백 기법으로 교체 가능.
    ///   - 전환 전 현재 소스를 영문으로 정착시키는 단계를 더 강화할 수 있음.
    ///
    /// - Parameters:
    ///   - targetID: 전환 목표 CJKV 입력소스 ID
    ///   - englishID: bounce 1단계에 사용할 영문 입력소스 ID
    private static func selectKoreanWorkaround(targetID: String, englishID: String) {
        // a. 이미 목표 소스 — 무동작
        guard InputSourceClassifier.needsSwitch(targetID: targetID, currentID: currentID()) else {
            return
        }

        // b. 영문(비-CJKV) 소스로 먼저 전환 — known-base 상태로 정착
        //    englishID 소스를 찾지 못하면 bounce 단계 생략하고 직접 선택 시도
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
            return
        }

        // d. compositor 강제 정착을 위해 동일 소스 재선택 (bounce)
        withInputSource(id: targetID) { korSourceAgain in
            TISSelectInputSource(korSourceAgain)
        }
    }
}
