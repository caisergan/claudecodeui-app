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
    private let store: UserDefaults

    private init() {
        self.store = .standard
    }

    init(store: UserDefaults) {
        self.store = store
    }

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

    // MARK: - Provider Preferences

    private let providerPreferencesKey = "providerPreferences"
    private let warmupSessionIdsKey = "warmupSessionIds"
    private let lastSuccessfulWarmupDatesKey = "lastSuccessfulWarmupDates"

    var providerPreferences: [String: ProviderPreference] {
        get {
            guard let data = store.data(forKey: providerPreferencesKey),
                  let decoded = try? JSONDecoder().decode([String: ProviderPreference].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                store.set(data, forKey: providerPreferencesKey)
            }
        }
    }

    var warmupSessionIds: [String: String] {
        get {
            store.dictionary(forKey: warmupSessionIdsKey) as? [String: String] ?? [:]
        }
        set {
            store.set(newValue, forKey: warmupSessionIdsKey)
        }
    }

    var lastSuccessfulWarmupDates: [String: Date] {
        get {
            guard let data = store.data(forKey: lastSuccessfulWarmupDatesKey),
                  let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                store.set(data, forKey: lastSuccessfulWarmupDatesKey)
            }
        }
    }

    func preference(for provider: AIProvider) -> ProviderPreference {
        providerPreferences[provider.rawValue] ?? .default
    }

    func setPreference(_ pref: ProviderPreference, for provider: AIProvider) {
        var all = providerPreferences
        all[provider.rawValue] = pref
        providerPreferences = all
    }

    func warmupSessionId(for provider: AIProvider) -> String? {
        warmupSessionIds[provider.rawValue]
    }

    func setWarmupSessionId(_ sessionId: String, for provider: AIProvider) {
        var all = warmupSessionIds
        all[provider.rawValue] = sessionId
        warmupSessionIds = all
    }

    func lastSuccessfulWarmupDate(for provider: AIProvider) -> Date? {
        lastSuccessfulWarmupDates[provider.rawValue]
    }

    func setLastSuccessfulWarmupDate(_ date: Date, for provider: AIProvider) {
        var all = lastSuccessfulWarmupDates
        all[provider.rawValue] = date
        lastSuccessfulWarmupDates = all
    }
}
