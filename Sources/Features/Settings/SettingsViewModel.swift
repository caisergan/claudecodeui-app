import Foundation
import SwiftUI

enum ColorSchemePreference: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showSignOutConfirmation: Bool = false
    @AppStorage("colorSchemePreference") var colorScheme: ColorSchemePreference = .system

    // MARK: - Provider State

    @Published var preferences: [AIProvider: ProviderPreference] = [:]
    @Published var errorBanner: String?

    private let storage: UserDefaultsStorage

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    init(storage: UserDefaultsStorage = .shared) {
        self.storage = storage
    }

    // MARK: - Lifecycle

    func loadProviderSettings() {
        let stored = storage.providerPreferences
        for provider in AIProvider.allCases {
            if let pref = stored[provider.rawValue] {
                preferences[provider] = pref
            } else {
                preferences[provider] = .default
            }
        }
    }

    // MARK: - Provider Configuration

    func toggleProvider(_ provider: AIProvider, isEnabled: Bool) {
        var pref = preferences[provider] ?? .default
        pref.isEnabled = isEnabled
        preferences[provider] = pref
        storage.setPreference(pref, for: provider)
    }

    func updateWarmupModel(_ provider: AIProvider, model: String) {
        var pref = preferences[provider] ?? .default
        pref.warmupModel = model
        preferences[provider] = pref
        storage.setPreference(pref, for: provider)
    }

    // MARK: - Sign Out

    func signOut(appState: AppState) {
        KeychainHelper.shared.clearAll()
        appState.isAuthenticated = false
        appState.currentUser = nil
    }
}