// SourceIDResolver — 입력소스 ID 해석 순수 함수
// 저장된 ID·사용 가능 목록·폴백으로 최종 소스 ID를 결정한다.

/// 입력소스 ID를 결정하는 순수 함수 네임스페이스
public enum SourceIDResolver {

    /// 저장된 ID, 사용 가능한 ID 목록, 폴백 ID로 최종 입력소스 ID를 결정한다.
    ///
    /// 우선순위:
    ///   1. stored가 nil이 아니고 available에 포함되면 → stored 반환
    ///   2. fallback이 available에 포함되면 → fallback 반환
    ///   3. available 첫 번째 항목 반환 (없으면 nil)
    ///
    /// - Parameters:
    ///   - stored: UserDefaults 등에 저장된 소스 ID (nil 가능)
    ///   - available: 시스템에서 열거한 사용 가능한 소스 ID 목록
    ///   - fallback: 저장값이 없거나 목록에 없을 때 사용할 기본 소스 ID
    /// - Returns: 결정된 소스 ID, available이 비어있고 폴백도 없으면 nil
    public static func resolveSourceID(
        stored: String?,
        available: [String],
        fallback: String
    ) -> String? {
        // 1. stored가 있고 available에 포함되면 그대로 사용
        if let stored, available.contains(stored) {
            return stored
        }

        // 2. fallback이 available에 포함되면 fallback 사용
        if available.contains(fallback) {
            return fallback
        }

        // 3. available 첫 번째 항목 또는 nil
        return available.first
    }
}
