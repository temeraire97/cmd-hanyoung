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
        // TISCreateInputSourceList: nil 필터 → 모든 소스, false = 활성 소스만 아님(전체)
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

    // MARK: - ID로 TISInputSource 탐색

    /// 입력소스 ID로 TISInputSource를 찾는다.
    /// enumerate()를 이용해 목록을 순회하므로 별도 리스트 누수 없음.
    static func find(id: String) -> TISInputSource? {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            return nil
        }
        let count = CFArrayGetCount(list)
        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(list, i) else { continue }
            let source = Unmanaged<TISInputSource>.fromOpaque(rawPtr).takeUnretainedValue()
            guard
                let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                (Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String) == id
            else { continue }
            // list가 살아있는 동안 source도 유효 — 호출자가 즉시 사용 후 버려야 함
            return source
        }
        return nil
    }

    // MARK: - 선택 (idempotent)

    /// 입력소스를 선택한다. 이미 현재 소스이면 무동작(idempotent).
    static func select(id: String) {
        guard InputSourceClassifier.needsSwitch(targetID: id, currentID: currentID()) else {
            return // 이미 현재 소스 — 무동작
        }
        guard let source = find(id: id) else {
            NSLog("[cmd-hanyoung] InputSource.select: ID 없음 — %@", id)
            return
        }
        TISSelectInputSource(source)
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
    /// - Parameter sourceID: 대상 한글 입력소스 ID (예: "com.apple.inputmethod.Korean.2SetKorean")
    static func forceKorean(sourceID: String) {
        selectKoreanWorkaround(sourceID: sourceID)
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
    ///   b. ABC(비-CJKV) 소스로 먼저 전환해 known-base 상태로 정착시킨다.
    ///   c. 목표 한글 소스를 TISSelectInputSource로 선택한다.
    ///   d. 다시 한 번 재선택해 compositor 강제 정착("bounce").
    ///
    /// 불확실성:
    ///   - 이 기법이 macOS 버전/하드웨어 조합 전체에서 동작하는지 미검증.
    ///   - 실제 착지 여부는 HITL 수동 검증 필수.
    ///
    /// 향후 개선 여지:
    ///   - Kawa 앱의 '다음 소스' 반복 폴백 기법으로 교체 가능.
    ///   - 전환 전 현재 소스를 ABC로 정착시키는 단계를 더 강화할 수 있음.
    ///
    /// - Parameter sourceID: 전환 목표 CJKV 입력소스 ID
    private static func selectKoreanWorkaround(sourceID: String) {
        // a. 이미 목표 소스 — 무동작
        guard InputSourceClassifier.needsSwitch(targetID: sourceID, currentID: currentID()) else {
            return
        }

        // b. ABC(비-CJKV) 소스로 먼저 전환 — known-base 상태로 정착
        // TODO(S5): 사용자 설정 영문 sourceID로 교체 예정 (지금은 ABC 하드코딩)
        let abcID = "com.apple.keylayout.ABC"
        if let abcSource = find(id: abcID) {
            TISSelectInputSource(abcSource)
        }

        // c. 목표 한글 소스 선택
        guard let korSource = find(id: sourceID) else {
            NSLog("[cmd-hanyoung] InputSource.selectKoreanWorkaround: 한글 소스 ID 없음 — %@", sourceID)
            return
        }
        TISSelectInputSource(korSource)

        // d. compositor 강제 정착을 위해 동일 소스 재선택 (bounce)
        if let korSourceAgain = find(id: sourceID) {
            TISSelectInputSource(korSourceAgain)
        }
    }
}
