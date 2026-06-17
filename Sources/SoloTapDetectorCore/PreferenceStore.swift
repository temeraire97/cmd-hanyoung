// PreferenceStore — 좌·우 ⌘ 입력소스 ID 사용자 설정 저장소
// KeyValueStore 프로토콜로 추상화해 UserDefaults 주입 및 테스트 가능하게 설계한다.
import Foundation

// MARK: - KeyValueStore 프로토콜

/// 문자열 키-값 저장소 추상화 — UserDefaults 또는 테스트용 딕셔너리로 교체 가능
public protocol KeyValueStore: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
}

// MARK: - UserDefaults 적합성

extension UserDefaults: KeyValueStore {
    public func set(_ value: String?, forKey key: String) {
        if let value {
            set(value as Any, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

// MARK: - PreferenceStore

/// 좌·우 ⌘ 키에 할당된 입력소스 ID를 저장·로드하는 설정 저장소
public final class PreferenceStore {

    // MARK: - UserDefaults 키

    public static let leftCmdSourceIDKey  = "leftCmdSourceID"
    public static let rightCmdSourceIDKey = "rightCmdSourceID"

    // MARK: - 의존성

    private let store: KeyValueStore

    // MARK: - Init

    /// - Parameter defaults: 주입할 UserDefaults 인스턴스 (기본: .standard)
    public convenience init(defaults: UserDefaults = .standard) {
        self.init(store: defaults)
    }

    /// - Parameter store: 주입할 KeyValueStore (테스트용)
    public init(store: KeyValueStore) {
        self.store = store
    }

    // MARK: - 좌 ⌘ 소스 ID

    /// 좌 ⌘ 에 할당된 입력소스 ID
    public var leftCmdSourceID: String? {
        get { store.string(forKey: Self.leftCmdSourceIDKey) }
        set { store.set(newValue, forKey: Self.leftCmdSourceIDKey) }
    }

    // MARK: - 우 ⌘ 소스 ID

    /// 우 ⌘ 에 할당된 입력소스 ID
    public var rightCmdSourceID: String? {
        get { store.string(forKey: Self.rightCmdSourceIDKey) }
        set { store.set(newValue, forKey: Self.rightCmdSourceIDKey) }
    }
}
