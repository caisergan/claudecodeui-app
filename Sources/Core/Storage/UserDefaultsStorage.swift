import Foundation

// MARK: - UserDefaultsStorage
//
// Type-safe @AppStorage-style wrapper for UserDefaults.
// Works outside SwiftUI views where @AppStorage is unavailable.
//
// Usage:
//   @UserDefault(key: "hasSeenOnboarding", default: false)
//   var hasSeenOnboarding: Bool

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    let store: UserDefaults

    init(key: String, default defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

// MARK: - UserDefaultsStorage (singleton)

final class UserDefaultsStorage {
    static let shared = UserDefaultsStorage()
    private init() {}

    @UserDefault(key: "hasCompletedOnboarding", default: false)
    var hasCompletedOnboarding: Bool

    @UserDefault(key: "preferredLanguage", default: "en")
    var preferredLanguage: String

    @UserDefault(key: "notificationsEnabled", default: true)
    var notificationsEnabled: Bool

    func reset() {
        hasCompletedOnboarding = false
        preferredLanguage = "en"
        notificationsEnabled = true
    }
}
