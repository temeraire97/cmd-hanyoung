// InputSourceClassifier — 입력소스 메타데이터 기반 언어 분류 (순수 함수, TIS 의존 없음)
// TIS에서 읽은 값을 그대로 받아 언어 종류를 판정한다.

/// 입력소스 언어 분류 결과
public enum InputSourceKind: Equatable {
    /// ASCII 레이아웃 (ABC, U.S. 등) — isASCIICapable == true
    case english
    /// CJKV 입력기 — category가 keyboard input method 계열이고 isASCIICapable == false
    case cjkv
    /// 분류 불가 (예: 다국어 IME 비ASCII 등 예외 케이스)
    case other
}

/// 입력소스 메타데이터로부터 언어 분류를 반환하는 순수 함수 네임스페이스
public enum InputSourceClassifier {

    // MARK: - TIS category 상수 (Carbon TIS 기준)

    /// kTISCategoryKeyboardInputSource 문자열 값
    public static let categoryKeyboardInputSource = "TISCategoryKeyboardInputSource"

    // MARK: - 분류 진입점

    /// 입력소스 메타데이터를 받아 InputSourceKind를 반환한다.
    ///
    /// - Parameters:
    ///   - category: TIS kTISPropertyInputSourceCategory 값 (nil이면 .other)
    ///   - isASCIICapable: TIS kTISPropertyInputSourceIsASCIICapable 값
    /// - Returns: 분류 결과
    public static func classify(
        category: String?,
        isASCIICapable: Bool
    ) -> InputSourceKind {
        guard let category else { return .other }

        if isASCIICapable {
            return .english
        }

        // isASCIICapable == false이고 키보드 입력 소스 카테고리인 경우 CJKV로 판정
        if category == categoryKeyboardInputSource {
            return .cjkv
        }

        return .other
    }

    // MARK: - 카테고리 술어

    /// 주어진 category가 키보드 입력소스 카테고리인지 판정한다.
    ///
    /// - Parameter category: TIS kTISPropertyInputSourceCategory 값 (nil이면 false)
    /// - Returns: category == categoryKeyboardInputSource 이면 true, 그 외(nil 포함) false
    public static func isKeyboardCategory(_ category: String?) -> Bool {
        category == categoryKeyboardInputSource
    }

    // MARK: - 선택 가능한 키보드 소스 술어

    /// 입력소스가 선택 가능한 키보드 소스인지 판정한다.
    ///
    /// 한국어 IME 상위 컨테이너(`com.apple.inputmethod.Korean`)는
    /// `kTISPropertyInputSourceIsSelectCapable == false`이므로 이 술어로 필터된다.
    /// 속성이 없는 소스(nil → true로 처리)는 표시 유지(안전 기본값).
    ///
    /// - Parameters:
    ///   - isSelectCapable: TIS kTISPropertyInputSourceIsSelectCapable 값 (nil → true 처리 후 전달)
    ///   - category: TIS kTISPropertyInputSourceCategory 값
    /// - Returns: isKeyboardCategory(category) && isSelectCapable
    public static func isSelectableKeyboardSource(
        isSelectCapable: Bool,
        category: String?
    ) -> Bool {
        isKeyboardCategory(category) && isSelectCapable
    }

    // MARK: - idempotency 판정

    /// 현재 입력소스가 목표 입력소스와 다른지 판정한다.
    /// 같으면 전환 불필요(false), 다르면 전환 필요(true).
    ///
    /// - Parameters:
    ///   - targetID: 전환하려는 입력소스 ID
    ///   - currentID: 현재 활성 입력소스 ID (nil이면 항상 전환 필요)
    /// - Returns: 전환이 필요하면 true
    public static func needsSwitch(targetID: String, currentID: String?) -> Bool {
        guard let currentID else { return true }
        return currentID != targetID
    }
}
