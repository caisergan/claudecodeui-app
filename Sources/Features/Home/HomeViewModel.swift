import Foundation
import Combine
import SwiftUI

private enum WarmupProjectPathResolutionError: LocalizedError {
    case healthCheckFailed(String)
    case unresolved

    var errorDescription: String? {
        switch self {
        case .healthCheckFailed(let reason):
            return "Warmup could not reach the backend health check. \(reason)"
        case .unresolved:
            return """
            Warmup could not resolve the server project path automatically. \
            Set a Warmup Project Path in Settings, set warmup_project_path in .env, \
            or ensure /health returns appInstallPath.
            """
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Usage & Warmup State
    @Published var preferences: [AIProvider: ProviderPreference] = [:]
    @Published var usageSummaries: [ProviderUsageSummary] = []
    @Published var lastUsageSyncDate: Date? = nil
    @Published var warmupStates: [AIProvider: WarmupState] = [:]
    @Published var lastSuccessfulWarmupDates: [AIProvider: Date] = [:]
    @Published var isLoadingUsage: Bool = false

    private let client: APIClient
    private let serverClient: APIClient
    private let storage: UserDefaultsStorage
    private var resetTasks: [AIProvider: Task<Void, Never>] = [:]
    private var resolvedWarmupProjectPath: String?

    var enabledProviders: [AIProvider] {
        AIProvider.allCases.filter { preferences[$0]?.isEnabled ?? true }
    }

    var usageProviders: [AIProvider] {
        enabledProviders.filter { $0 != .claude }
    }

    init(
        client: APIClient = .shared,
        serverClient: APIClient = .serverShared,
        storage: UserDefaultsStorage = .shared
    ) {
        self.client = client
        self.serverClient = serverClient
        self.storage = storage
    }

    // MARK: - Conversations

    func loadConversations() async {
        if AppConfig.disableAuthentication {
            loadPreviewConversations()
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await client.request(
                Endpoint(path: "/conversations"),
                responseType: [Conversation].self
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func createConversation() {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
    }

    // MARK: - Settings & Usage

    func loadProviderSettings() {
        let stored = storage.providerPreferences
        for provider in AIProvider.allCases {
            if let pref = stored[provider.rawValue] {
                preferences[provider] = pref
            } else {
                preferences[provider] = .default
            }
            if warmupStates[provider] == nil {
                warmupStates[provider] = .idle
            }

            if let lastSuccessfulWarmupDate = storage.lastSuccessfulWarmupDate(for: provider) {
                lastSuccessfulWarmupDates[provider] = lastSuccessfulWarmupDate
            } else {
                lastSuccessfulWarmupDates.removeValue(forKey: provider)
            }
        }
    }

    func refreshUsage(forceRefresh: Bool = false) async {
        isLoadingUsage = true
        errorMessage = nil
        showError = false
        defer { isLoadingUsage = false }

        let providers = usageProviders
        guard providers.isNotEmpty else {
            usageSummaries = []
            return
        }

        do {
            var resultsByProvider: [AIProvider: ProviderUsageResult] = [:]

            for provider in providers {
                let response = try await client.request(
                    API.usageLimits(provider: provider.rawValue, refresh: forceRefresh),
                    responseType: UsageLimitsResponse.self
                )

                if let result = response.providers[provider.rawValue] {
                    resultsByProvider[provider] = result
                }
            }

            let updatedSummaries = providers.map { provider in
                if let result = resultsByProvider[provider] {
                    return result.usageSummary(for: provider)
                }

                return ProviderUsageSummary(
                    provider: provider,
                    status: .unknown,
                    state: nil,
                    quotaWindows: [],
                    statusMessage: "No usage data available",
                    metadata: nil,
                    resetTime: nil
                )
            }

            applyUsageSnapshot(updatedSummaries, syncedAt: Date())
        } catch {
            if AppConfig.disableAuthentication {
                loadPreviewUsage()
                return
            }

            if isUsageEndpointUnavailable(error) {
                errorMessage = nil
                showError = false
                let unsupportedSummaries = providers.map { provider in
                    ProviderUsageSummary(
                        provider: provider,
                        status: .unsupported,
                        state: "unsupported",
                        quotaWindows: [],
                        statusMessage: "Usage endpoint is unavailable on this server",
                        metadata: nil,
                        resetTime: nil
                    )
                }
                applyUsageSnapshot(unsupportedSummaries, syncedAt: Date())
                return
            }

            errorMessage = "Failed to load usage: \(error.localizedDescription)"
            showError = true
        }
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
        let apiKey = AppConfig.resolvedAgentAPIKey

        if apiKey?.isBlank != false {
            presentWarmupFailure(
                "Warmup requires a ClaudeCodeUI API key.",
                for: provider
            )
            scheduleReset(for: provider)
            return
        }

        let projectPath: String
        do {
            projectPath = try await resolveWarmupProjectPath()
        } catch {
            presentWarmupFailure(error.localizedDescription, for: provider)
            scheduleReset(for: provider)
            return
        }

        let payload = WarmupRequestPayload(
            provider: provider,
            model: model,
            sessionId: sessionId,
            projectPath: projectPath
        )

        do {
            let response = try await client.request(
                API.agent(body: payload),
                responseType: WarmupResponse.self
            )

            let effectiveSessionId = response.sessionId?.isBlank == false
                ? response.sessionId
                : sessionId
            let effectiveProjectPath = response.projectPath?.isBlank == false
                ? response.projectPath
                : projectPath

            if let effectiveSessionId, !effectiveSessionId.isBlank {
                let cachedMessages = response.messages.compactMap { $0.asAppMessage() }
                let existingMessages = storage.agentSessionContext(for: provider)?.messages ?? []
                let context = AgentSessionContext(
                    sessionId: effectiveSessionId,
                    projectPath: effectiveProjectPath,
                    messages: cachedMessages.isNotEmpty ? cachedMessages : existingMessages
                )

                storage.setAgentSessionContext(context, for: provider)
            }

            let completedAt = Date()
            storage.setLastSuccessfulWarmupDate(completedAt, for: provider)
            lastSuccessfulWarmupDates[provider] = completedAt
            warmupStates[provider] = .success
        } catch {
            presentWarmupFailure(error.localizedDescription, for: provider)
        }

        scheduleReset(for: provider)
    }

    private func resolveWarmupProjectPath() async throws -> String {
        if let configuredProjectPath = AppConfig.defaultProjectPath, !configuredProjectPath.isBlank {
            return configuredProjectPath
        }

        if let resolvedWarmupProjectPath, !resolvedWarmupProjectPath.isBlank {
            return resolvedWarmupProjectPath
        }

        do {
            let health = try await serverClient.request(
                API.health,
                responseType: ServerHealthResponse.self
            )

            if let appInstallPath = health.appInstallPath, !appInstallPath.isBlank {
                resolvedWarmupProjectPath = appInstallPath
                return appInstallPath
            }
        } catch {
            throw WarmupProjectPathResolutionError.healthCheckFailed(error.localizedDescription)
        }

        throw WarmupProjectPathResolutionError.unresolved
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

    func loadCachedUsage() {
        guard !AppConfig.disableAuthentication else {
            return
        }

        guard let snapshot = storage.usageCacheSnapshot,
              snapshot.baseURL == client.resolvedBaseURL.absoluteString else {
            return
        }

        usageSummaries = snapshot.summaries.filter { usageProviders.contains($0.provider) }
        lastUsageSyncDate = snapshot.syncedAt
    }

    private func loadPreviewConversations() {
        errorMessage = nil
        showError = false
        conversations = [
            Conversation(
                title: "Preview Conversation",
                messages: [
                    Message(
                        role: .assistant,
                        content: "Preview mode is active. Live conversations require app authentication."
                    )
                ]
            )
        ]
    }

    private func loadPreviewUsage() {
        errorMessage = nil
        showError = false
        usageSummaries = usageProviders.map { provider in
            ProviderUsageSummary(
                provider: provider,
                status: .preview,
                state: "preview",
                quotaWindows: [],
                statusMessage: "Preview mode active",
                metadata: nil,
                resetTime: nil
            )
        }
        lastUsageSyncDate = nil
    }

    private func presentWarmupFailure(
        _ message: String,
        for provider: AIProvider
    ) {
        warmupStates[provider] = .failure(message)
        errorMessage = "\(provider.displayName) warmup failed: \(message)"
        showError = true
    }

    private func isUsageEndpointUnavailable(_ error: Error) -> Bool {
        guard case APIError.serverError(let message) = error else {
            return false
        }

        return message.contains("/usage-limits") && message.contains("received HTML")
    }

    private func applyUsageSnapshot(
        _ summaries: [ProviderUsageSummary],
        syncedAt: Date
    ) {
        usageSummaries = summaries
        lastUsageSyncDate = syncedAt
        storage.usageCacheSnapshot = UsageCacheSnapshot(
            baseURL: client.resolvedBaseURL.absoluteString,
            syncedAt: syncedAt,
            summaries: summaries
        )
    }
}
