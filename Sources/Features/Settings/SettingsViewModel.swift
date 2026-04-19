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
    @Published var usageSummaries: [ProviderUsageSummary] = []
    @Published var warmupStates: [AIProvider: WarmupState] = [:]
    @Published var isLoadingUsage: Bool = false
    @Published var errorBanner: String?

    private let client: APIClient
    private let storage: UserDefaultsStorage
    private var resetTasks: [AIProvider: Task<Void, Never>] = [:]

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var enabledProviders: [AIProvider] {
        AIProvider.allCases.filter { preferences[$0]?.isEnabled ?? true }
    }

    init(client: APIClient = .shared, storage: UserDefaultsStorage = .shared) {
        self.client = client
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
            warmupStates[provider] = .idle
        }
    }

    func refreshUsage() async {
        isLoadingUsage = true
        errorBanner = nil
        defer { isLoadingUsage = false }

        do {
            let response = try await client.request(
                API.usageLimits(),
                responseType: UsageLimitsResponse.self
            )
            var summaries: [ProviderUsageSummary] = []
            for provider in enabledProviders {
                if let result = response.providers[provider.rawValue] {
                    let summary = result.message ?? result.state ?? "Available"
                    summaries.append(ProviderUsageSummary(
                        provider: provider,
                        summary: summary,
                        resetTime: result.resetAt,
                        state: result.state
                    ))
                } else {
                    summaries.append(ProviderUsageSummary(
                        provider: provider,
                        summary: "Unavailable",
                        resetTime: nil,
                        state: nil
                    ))
                }
            }
            usageSummaries = summaries
        } catch {
            errorBanner = "Failed to load usage: \(error.localizedDescription)"
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

    // MARK: - Warmup

    func warmupProvider(_ provider: AIProvider) async {
        guard preferences[provider]?.isEnabled ?? true else { return }

        // Cancel any pending reset timer for this provider
        resetTasks[provider]?.cancel()
        resetTasks[provider] = nil

        warmupStates[provider] = .loading

        let pref = preferences[provider] ?? .default
        let model: String? = pref.warmupModel.isEmpty ? nil : pref.warmupModel
        let sessionId = storage.warmupSessionId(for: provider)

        let payload = WarmupRequestPayload(
            provider: provider,
            model: model,
            sessionId: sessionId,
            projectPath: AppConfig.defaultProjectPath
        )

        do {
            let response = try await client.request(
                API.agent(body: payload),
                responseType: WarmupResponse.self
            )

            // Store session ID on first success
            if let newSessionId = response.sessionId,
               storage.warmupSessionId(for: provider) == nil {
                storage.setWarmupSessionId(newSessionId, for: provider)
            }

            warmupStates[provider] = .success
        } catch {
            warmupStates[provider] = .failure(error.localizedDescription)
        }

        scheduleReset(for: provider)
    }

    private func scheduleReset(for provider: AIProvider) {
        resetTasks[provider]?.cancel()
        resetTasks[provider] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.warmupStates[provider] = .idle
        }
    }

    func cancelAllResetTimers() {
        for (_, task) in resetTasks {
            task.cancel()
        }
        resetTasks.removeAll()
    }

    // MARK: - Sign Out

    func signOut(appState: AppState) {
        cancelAllResetTimers()
        KeychainHelper.shared.clearAll()
        appState.isAuthenticated = false
        appState.currentUser = nil
    }
}
