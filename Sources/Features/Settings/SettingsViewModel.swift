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
    @Published var apiBaseURLOverrideText: String = ""
    @Published var agentAPIKeyText: String = ""
    @Published var warmupProjectPathText: String = ""
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

        apiBaseURLOverrideText = storage.apiBaseURLOverride ?? ""
        agentAPIKeyText = KeychainHelper.shared.read(key: .agentAPIKey) ?? ""
        warmupProjectPathText = storage.warmupProjectPathOverride ?? ""
        errorBanner = nil
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

    // MARK: - Connection Configuration

    var activeAPIBaseURL: String {
        AppConfig.apiBaseURL.absoluteString
    }

    var apiBaseURLSourceLabel: String {
        AppConfig.apiBaseURLSource.displayName
    }

    var agentAPIKeySourceLabel: String {
        AppConfig.agentAPIKeySource.displayName
    }

    var warmupProjectPathSourceLabel: String {
        AppConfig.defaultProjectPathSource.displayName
    }

    @discardableResult
    func saveAPIBaseURLOverride() -> Bool {
        let trimmed = apiBaseURLOverrideText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isBlank else {
            clearAPIBaseURLOverride()
            return true
        }

        guard let normalizedURL = AppConfig.normalizedAPIBaseURL(from: trimmed) else {
            errorBanner = "Enter a valid API base URL."
            return false
        }

        storage.apiBaseURLOverride = normalizedURL.absoluteString
        apiBaseURLOverrideText = normalizedURL.absoluteString
        errorBanner = nil
        objectWillChange.send()
        return true
    }

    func clearAPIBaseURLOverride() {
        storage.apiBaseURLOverride = nil
        apiBaseURLOverrideText = ""
        errorBanner = nil
        objectWillChange.send()
    }

    func saveAgentAPIKey() {
        let trimmed = agentAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isBlank {
            KeychainHelper.shared.delete(key: .agentAPIKey)
            agentAPIKeyText = ""
        } else {
            KeychainHelper.shared.save(trimmed, key: .agentAPIKey)
            agentAPIKeyText = trimmed
        }

        errorBanner = nil
        objectWillChange.send()
    }

    func clearAgentAPIKey() {
        KeychainHelper.shared.delete(key: .agentAPIKey)
        agentAPIKeyText = ""
        errorBanner = nil
        objectWillChange.send()
    }

    func saveWarmupProjectPath() {
        let trimmed = warmupProjectPathText.trimmingCharacters(in: .whitespacesAndNewlines)
        storage.warmupProjectPathOverride = trimmed.isBlank ? nil : trimmed
        warmupProjectPathText = storage.warmupProjectPathOverride ?? ""
        errorBanner = nil
        objectWillChange.send()
    }

    func clearWarmupProjectPath() {
        storage.warmupProjectPathOverride = nil
        warmupProjectPathText = ""
        errorBanner = nil
        objectWillChange.send()
    }

    func refreshRuntimeConfiguration(appState: AppState) async {
        await appState.restoreSession()
    }

    // MARK: - Sign Out

    func signOut(appState: AppState) {
        KeychainHelper.shared.clearAll()
        appState.isAuthenticated = false
        appState.currentUser = nil
    }
}
