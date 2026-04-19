import Foundation

// MARK: - AIProvider

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case claude
    case codex
    case cursor
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .gemini: return "Gemini"
        }
    }

    var supportedWarmupModels: [String] {
        switch self {
        case .claude:
            return [
                "sonnet",
                "opus",
                "haiku",
                "opusplan",
                "sonnet[1m]",
                "opus[1m]"
            ]
        case .codex:
            return [
                "gpt-5.4",
                "gpt-5.4-mini",
                "gpt-5.3-codex",
                "gpt-5.2-codex",
                "gpt-5.2",
                "gpt-5.1-codex-max",
                "o3",
                "o4-mini"
            ]
        case .cursor:
            return []
        case .gemini:
            return [
                "gemini-3.1-pro-preview",
                "gemini-3-pro-preview",
                "gemini-3-flash-preview",
                "gemini-2.5-flash",
                "gemini-2.5-pro",
                "gemini-2.0-flash-lite",
                "gemini-2.0-flash",
                "gemini-2.0-pro-experimental",
                "gemini-2.0-flash-thinking"
            ]
        }
    }

    func warmupModelMenuOptions(including currentSelection: String) -> [String] {
        let models = supportedWarmupModels
        guard !models.isEmpty else { return [] }
        guard !currentSelection.isEmpty, !models.contains(currentSelection) else {
            return models
        }
        return [currentSelection] + models
    }
}

// MARK: - Provider Preference

struct ProviderPreference: Codable, Equatable {
    var isEnabled: Bool
    var warmupModel: String

    static let `default` = ProviderPreference(isEnabled: true, warmupModel: "")
}

// MARK: - Warmup State

enum WarmupState: Equatable {
    case idle
    case loading
    case success
    case failure(String)
}

// MARK: - Warmup Request Payload

struct WarmupRequestPayload: Codable {
    let message: String
    let provider: String
    let model: String?
    let sessionId: String?
    let projectPath: String?
    let githubUrl: String?
    let stream: Bool

    init(
        provider: AIProvider,
        model: String? = nil,
        sessionId: String? = nil,
        projectPath: String? = nil,
        githubUrl: String? = nil
    ) {
        self.message = "ping"
        self.provider = provider.rawValue
        self.model = model
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.githubUrl = githubUrl
        self.stream = false
    }
}

// MARK: - Warmup Response

struct WarmupResponse: Codable {
    let success: Bool
    let sessionId: String?
}

// MARK: - Health Response

struct ServerHealthResponse: Codable {
    let status: String
    let timestamp: String
    let installMode: String?
    let appInstallPath: String?
}

// MARK: - Usage Limits Response

struct UsageLimitsResponse: Codable {
    let success: Bool
    let checkedAt: String?
    let providers: [String: ProviderUsageResult]
}

struct ProviderUsageResult: Codable {
    let provider: String?
    let installed: Bool?
    let authenticated: Bool?
    let state: String?
    let limitReached: Bool?
    let resetAt: String?
    let message: String?
    let supportLevel: String?
}

// MARK: - CLI Status Response

struct CLIStatusResponse: Codable {
    let installed: Bool?
    let authenticated: Bool?
    let email: String?
    let method: String?
    let error: String?
}

// MARK: - Display Models

struct ProviderUsageSummary: Identifiable {
    let provider: AIProvider
    let summary: String
    let resetTime: String?
    let state: String?

    var id: String { provider.rawValue }
}
