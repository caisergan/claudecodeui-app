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
    let account: String?
    let authMethod: String?
    let authError: String?
    let planType: String?
    let organization: String?
    let state: String?
    let limitReached: Bool?
    let resetAt: String?
    let lastSeenAt: String?
    let message: String?
    let supportLevel: String?
    let supportsRemainingQuota: Bool?
    let scannedFiles: Int?
    let source: String?
    let limits: ProviderUsageLimits?
    let credits: ProviderUsageCredits?
    let spendControl: ProviderUsageSpendControl?
}

struct ProviderUsageLimits: Codable {
    let primary: UsageQuotaWindow?
    let secondary: UsageQuotaWindow?
    let codeReviewPrimary: UsageQuotaWindow?
    let codeReviewSecondary: UsageQuotaWindow?
    let additional: [UsageQuotaWindow]?
}

struct UsageQuotaWindow: Codable {
    let name: String?
    let limitId: String?
    let usedPercent: Double?
    let remainingPercent: Double?
    let limitWindowSeconds: Double?
    let resetAfterSeconds: Double?
    let resetAt: String?
}

struct ProviderUsageCredits: Codable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let overageLimitReached: Bool?
    let balance: Double?
    let approxLocalMessages: Double?
    let approxCloudMessages: Double?
}

struct ProviderUsageSpendControl: Codable {
    let reached: Bool?
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

enum ProviderUsageStatus: String, Codable, Equatable {
    case ready
    case limited
    case actionRequired
    case unsupported
    case preview
    case unknown

    var badgeTitle: String {
        switch self {
        case .ready: return "Live"
        case .limited: return "Limited"
        case .actionRequired: return "Auth"
        case .unsupported: return "N/A"
        case .preview: return "Preview"
        case .unknown: return "Unknown"
        }
    }
}

struct QuotaWindowDisplay: Codable, Equatable, Identifiable {
    let label: String
    let remaining: Double

    var id: String { label }
}

struct ProviderUsageSummary: Codable, Equatable, Identifiable {
    let provider: AIProvider
    let status: ProviderUsageStatus
    let state: String?
    let quotaWindows: [QuotaWindowDisplay]
    let statusMessage: String?
    let metadata: String?
    let resetTime: Date?

    var id: String { provider.rawValue }
}

struct UsageCacheSnapshot: Codable, Equatable {
    let baseURL: String
    let syncedAt: Date
    let summaries: [ProviderUsageSummary]
}

extension ProviderUsageResult {
    func usageSummary(for provider: AIProvider) -> ProviderUsageSummary {
        let status = displayStatus

        let windows: [QuotaWindowDisplay] = prioritizedWindows(for: provider)
            .compactMap { slot, window -> QuotaWindowDisplay? in
                guard let remaining = remainingPercent(for: window) else { return nil }
                let label = windowLabel(for: provider, slot: slot, window: window)
                return QuotaWindowDisplay(label: label, remaining: remaining)
            }

        let statusMsg: String?
        if windows.isNotEmpty {
            statusMsg = nil
        } else if let creditText = creditHeadline {
            statusMsg = creditText
        } else {
            statusMsg = statusHeadline
        }

        return ProviderUsageSummary(
            provider: provider,
            status: status,
            state: state,
            quotaWindows: Array(windows.prefix(2)),
            statusMessage: statusMsg,
            metadata: metadataLine,
            resetTime: resetDate
        )
    }

    private var displayStatus: ProviderUsageStatus {
        switch state {
        case "available":
            return .ready
        case "limit_reached", "not_allowed":
            return .limited
        case "auth_required", "auth_expired":
            return .actionRequired
        case "unsupported", "api_key_mode_unsupported", "credential_store_unsupported", "policy_disabled":
            return .unsupported
        case "preview":
            return .preview
        default:
            return .unknown
        }
    }

    private var statusHeadline: String {
        switch state {
        case "preview":
            return "Preview mode is active."
        case "available":
            return "Usage data is current."
        case "limit_reached":
            return "Usage limit reached."
        case "auth_required":
            return "Sign in to fetch usage."
        case "auth_expired":
            return "Re-authenticate to refresh usage."
        case "not_allowed":
            return "Requests are currently blocked."
        case "api_key_mode_unsupported":
            return "Quota windows are unavailable in API-key mode."
        case "credential_store_unsupported":
            return "Usage is not readable from the current credential store."
        case "historical_limit_signal":
            return "Recent limit signal is no longer active."
        case "no_limit_signal_detected":
            return "No recent limit signal was detected."
        case "unsupported":
            return "Usage detection is not supported yet."
        case "policy_disabled":
            return "Usage checks are temporarily disabled."
        case "error":
            return trimmedMessage(default: "Usage lookup failed.")
        default:
            return trimmedMessage(default: "No usage data available.")
        }
    }

    private var metadataLine: String? {
        var parts: [String] = []

        if let planType, !planType.isBlank {
            parts.append(planType)
        }

        if let organization, !organization.isBlank {
            parts.append(organization)
        } else if let account, !account.isBlank {
            parts.append(account)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var resetDate: Date? {
        if let resetAt, !resetAt.isBlank,
           let date = UsageFormatting.parseTimestamp(resetAt) {
            return date
        }
        if let windowResetAt = limits?.primary?.resetAt,
           !windowResetAt.isBlank,
           let date = UsageFormatting.parseTimestamp(windowResetAt) {
            return date
        }
        if let seconds = limits?.primary?.resetAfterSeconds, seconds > 0 {
            return Date(timeIntervalSinceNow: seconds)
        }
        return nil
    }

    private var creditHeadline: String? {
        if let credits, credits.unlimited == true {
            return "Unlimited extra usage"
        }
        if let approxLocalMessages = credits?.approxLocalMessages {
            return "\(formattedPercentlessNumber(approxLocalMessages)) local messages remaining"
        }
        return nil
    }


    private func prioritizedWindows(for provider: AIProvider) -> [(UsageWindowSlot, UsageQuotaWindow)] {
        var windows: [(UsageWindowSlot, UsageQuotaWindow)] = []

        if let primary = limits?.primary {
            windows.append((.primary, primary))
        }
        if let secondary = limits?.secondary {
            windows.append((.secondary, secondary))
        }
        if let reviewPrimary = limits?.codeReviewPrimary {
            windows.append((.codeReviewPrimary, reviewPrimary))
        }
        if let reviewSecondary = limits?.codeReviewSecondary {
            windows.append((.codeReviewSecondary, reviewSecondary))
        }
        for additional in limits?.additional ?? [] {
            windows.append((.additional, additional))
        }

        if windows.isEmpty, provider == .claude, let resetAt, !resetAt.isBlank, limitReached == true {
            return []
        }

        return windows
    }

    private func remainingPercent(for window: UsageQuotaWindow) -> Double? {
        // Claude usage normalization in older backend builds could send
        // percentages multiplied by 100 (e.g. 5200 instead of 52). If that
        // happens, prefer the corrected usedPercent over the stale remainingPercent.
        if let rawUsedPercent = window.usedPercent,
           rawUsedPercent > 100,
           let correctedUsedPercent = normalizedPercent(rawUsedPercent) {
            return max(0, min(100, 100 - correctedUsedPercent))
        }

        if let remaining = normalizedPercent(window.remainingPercent) {
            return remaining
        }

        if let used = normalizedPercent(window.usedPercent) {
            return max(0, min(100, 100 - used))
        }

        return nil
    }

    private func normalizedPercent(_ value: Double?) -> Double? {
        guard let value else { return nil }
        let normalized = value > 100 ? value / 100 : value
        return max(0, min(100, normalized))
    }

    private func windowLabel(
        for provider: AIProvider,
        slot: UsageWindowSlot,
        window: UsageQuotaWindow
    ) -> String {
        if let name = window.name, !name.isBlank {
            return name.prettifiedUsageWindowName
        }

        if let seconds = window.limitWindowSeconds,
           let duration = UsageFormatting.shortDuration(seconds: seconds) {
            switch slot {
            case .codeReviewPrimary, .codeReviewSecondary:
                return "review \(duration)"
            default:
                return duration
            }
        }

        switch (provider, slot) {
        case (.claude, .primary):
            return "5h"
        case (.claude, .secondary):
            return "7d"
        case (_, .codeReviewPrimary), (_, .codeReviewSecondary):
            return "review"
        case (_, .additional):
            return "extra"
        case (_, .primary):
            return "primary"
        case (_, .secondary):
            return "secondary"
        }
    }

    private func formattedPercentlessNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func trimmedMessage(default defaultMessage: String) -> String {
        guard let message, !message.isBlank else {
            return defaultMessage
        }

        if message.isGenericUsageSuccessMessage {
            return defaultMessage
        }

        return message.truncated(to: 90)
    }
}

private enum UsageWindowSlot {
    case primary
    case secondary
    case codeReviewPrimary
    case codeReviewSecondary
    case additional
}

private enum UsageFormatting {
    private static let internetDateTimeFormatter = ISO8601DateFormatter()
    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseTimestamp(_ value: String) -> Date? {
        fractionalSecondsFormatter.date(from: value)
            ?? internetDateTimeFormatter.date(from: value)
    }

    static func shortDuration(seconds: Double) -> String? {
        guard seconds > 0 else { return nil }

        let roundedSeconds = Int(seconds.rounded())

        if roundedSeconds % 86_400 == 0 {
            return "\(roundedSeconds / 86_400)d"
        }

        if roundedSeconds % 3_600 == 0 {
            return "\(roundedSeconds / 3_600)h"
        }

        if roundedSeconds >= 3_600 {
            return "\(Int((seconds / 3_600).rounded()))h"
        }

        if roundedSeconds % 60 == 0 {
            return "\(roundedSeconds / 60)m"
        }

        if roundedSeconds >= 60 {
            return "\(Int((seconds / 60).rounded()))m"
        }

        return "\(roundedSeconds)s"
    }
}

private extension String {
    var isGenericUsageSuccessMessage: Bool {
        lowercased().contains("usage data was fetched successfully")
    }

    var prettifiedUsageWindowName: String {
        lowercased()
            .replacingOccurrences(of: "seven_day", with: "7d")
            .replacingOccurrences(of: "five_hour", with: "5h")
            .replacingOccurrences(of: "_", with: " ")
    }
}
