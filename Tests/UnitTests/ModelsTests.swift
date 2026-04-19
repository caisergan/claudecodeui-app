import XCTest
@testable import ClaudeCodeUI

final class ModelsTests: XCTestCase {

    // MARK: - Message

    func testMessageDefaultsToNow() {
        let before = Date.now
        let msg = Message(role: .user, content: "Hello")
        let after = Date.now
        XCTAssertGreaterThanOrEqual(msg.timestamp, before)
        XCTAssertLessThanOrEqual(msg.timestamp, after)
    }

    func testMessageEquality() {
        let id = UUID().uuidString
        let timestamp = Date.now
        let a = Message(id: id, role: .user, content: "Hi", timestamp: timestamp)
        let b = Message(id: id, role: .user, content: "Hi", timestamp: timestamp)
        XCTAssertEqual(a, b)
    }

    func testAuthenticatedUserPayloadDecodesIntegerIDs() throws {
        let data = #"{"id":42,"username":"alice"}"#.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AuthenticatedUserPayload.self, from: data)

        XCTAssertEqual(payload.id, "42")
        XCTAssertEqual(payload.username, "alice")
        XCTAssertEqual(payload.asAppUser(), User(id: "42", name: "alice", email: "alice"))
    }

    // MARK: - Conversation

    func testConversationDefaultsToEmpty() {
        let c = Conversation()
        XCTAssertTrue(c.messages.isEmpty)
        XCTAssertEqual(c.title, "New Conversation")
    }

    // MARK: - String Extensions

    func testIsBlank() {
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("".isBlank)
        XCTAssertFalse("hello".isBlank)
    }

    func testTruncated() {
        let s = "Hello, world!"
        XCTAssertEqual(s.truncated(to: 5), "Hello…")
        XCTAssertEqual(s.truncated(to: 100), s)
    }

    // MARK: - Collection Extensions

    func testSafeIndex() {
        let arr = [1, 2, 3]
        XCTAssertEqual(arr.safe(0), 1)
        XCTAssertNil(arr.safe(10))
    }

    // MARK: - Provider Models

    func testSupportedWarmupModelsAreHardcodedPerProvider() {
        XCTAssertEqual(AIProvider.codex.supportedWarmupModels, [
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.3-codex",
            "gpt-5.2-codex",
            "gpt-5.2",
            "gpt-5.1-codex-max",
            "o3",
            "o4-mini"
        ])

        XCTAssertEqual(AIProvider.claude.supportedWarmupModels, [
            "sonnet",
            "opus",
            "haiku",
            "opusplan",
            "sonnet[1m]",
            "opus[1m]"
        ])

        XCTAssertEqual(AIProvider.gemini.supportedWarmupModels, [
            "gemini-3.1-pro-preview",
            "gemini-3-pro-preview",
            "gemini-3-flash-preview",
            "gemini-2.5-flash",
            "gemini-2.5-pro",
            "gemini-2.0-flash-lite",
            "gemini-2.0-flash",
            "gemini-2.0-pro-experimental",
            "gemini-2.0-flash-thinking"
        ])

        XCTAssertTrue(AIProvider.cursor.supportedWarmupModels.isEmpty)
    }

    func testWarmupModelMenuOptionsPreserveSavedCustomSelection() {
        let options = AIProvider.claude.warmupModelMenuOptions(including: "sonnet-4")

        XCTAssertEqual(options.first, "sonnet-4")
        XCTAssertEqual(options.dropFirst().first, "sonnet")
    }

    func testWarmupModelMenuOptionsDoNotDuplicateKnownSelection() {
        let options = AIProvider.codex.warmupModelMenuOptions(including: "gpt-5.4")

        XCTAssertEqual(options.first, "gpt-5.4")
        XCTAssertEqual(options.filter { $0 == "gpt-5.4" }.count, 1)
    }

    func testProviderUsageSummaryFormatsQuotaWindowsAndMetadata() {
        let result = ProviderUsageResult(
            provider: "codex",
            installed: true,
            authenticated: true,
            account: "dev@example.com",
            authMethod: "chatgpt",
            authError: nil,
            planType: "ChatGPT Plus",
            organization: nil,
            state: "available",
            limitReached: false,
            resetAt: nil,
            lastSeenAt: nil,
            message: "Codex usage data was fetched successfully.",
            supportLevel: "direct_api",
            supportsRemainingQuota: true,
            scannedFiles: nil,
            source: "codex_wham_usage_api",
            limits: ProviderUsageLimits(
                primary: UsageQuotaWindow(
                    name: nil,
                    limitId: nil,
                    usedPercent: nil,
                    remainingPercent: 82,
                    limitWindowSeconds: 18_000,
                    resetAfterSeconds: nil,
                    resetAt: nil
                ),
                secondary: UsageQuotaWindow(
                    name: nil,
                    limitId: nil,
                    usedPercent: nil,
                    remainingPercent: 41,
                    limitWindowSeconds: 604_800,
                    resetAfterSeconds: nil,
                    resetAt: nil
                ),
                codeReviewPrimary: nil,
                codeReviewSecondary: nil,
                additional: []
            ),
            credits: nil,
            spendControl: nil
        )

        let summary = result.usageSummary(for: .codex)

        XCTAssertEqual(summary.status, .ready)
        XCTAssertEqual(summary.quotaWindows.count, 2)
        XCTAssertEqual(summary.quotaWindows[0].label, "5h")
        XCTAssertEqual(summary.quotaWindows[0].remaining, 82)
        XCTAssertEqual(summary.quotaWindows[1].label, "7d")
        XCTAssertEqual(summary.quotaWindows[1].remaining, 41)
        XCTAssertNil(summary.statusMessage)
        XCTAssertEqual(summary.metadata, "ChatGPT Plus \u{2022} dev@example.com")
    }

    func testProviderUsageSummaryMapsAuthRequiredState() {
        let result = ProviderUsageResult(
            provider: "claude",
            installed: true,
            authenticated: false,
            account: nil,
            authMethod: nil,
            authError: nil,
            planType: nil,
            organization: nil,
            state: "auth_required",
            limitReached: nil,
            resetAt: nil,
            lastSeenAt: nil,
            message: "Claude OAuth token not found.",
            supportLevel: "best_effort",
            supportsRemainingQuota: false,
            scannedFiles: nil,
            source: nil,
            limits: nil,
            credits: nil,
            spendControl: nil
        )

        let summary = result.usageSummary(for: .claude)

        XCTAssertEqual(summary.status, .actionRequired)
        XCTAssertEqual(summary.statusMessage, "Sign in to fetch usage.")
        XCTAssertTrue(summary.quotaWindows.isEmpty)
        XCTAssertNil(summary.metadata)
    }

    func testClaudeUsageSummaryCorrectsLegacyOverScaledPercentages() {
        let result = ProviderUsageResult(
            provider: "claude",
            installed: true,
            authenticated: true,
            account: "claude@example.com",
            authMethod: "oauth",
            authError: nil,
            planType: "pro",
            organization: nil,
            state: "available",
            limitReached: false,
            resetAt: nil,
            lastSeenAt: nil,
            message: "Claude usage data was fetched successfully.",
            supportLevel: "direct_api",
            supportsRemainingQuota: true,
            scannedFiles: nil,
            source: "claude_oauth_usage_api",
            limits: ProviderUsageLimits(
                primary: UsageQuotaWindow(
                    name: nil,
                    limitId: nil,
                    usedPercent: 5200,
                    remainingPercent: 0,
                    limitWindowSeconds: nil,
                    resetAfterSeconds: nil,
                    resetAt: nil
                ),
                secondary: UsageQuotaWindow(
                    name: nil,
                    limitId: nil,
                    usedPercent: 3800,
                    remainingPercent: 0,
                    limitWindowSeconds: nil,
                    resetAfterSeconds: nil,
                    resetAt: nil
                ),
                codeReviewPrimary: nil,
                codeReviewSecondary: nil,
                additional: []
            ),
            credits: nil,
            spendControl: nil
        )

        let summary = result.usageSummary(for: .claude)

        XCTAssertEqual(summary.quotaWindows.count, 2)
        XCTAssertEqual(summary.quotaWindows[0].label, "5h")
        XCTAssertEqual(summary.quotaWindows[0].remaining, 48, accuracy: 0.1)
        XCTAssertEqual(summary.quotaWindows[1].label, "7d")
        XCTAssertEqual(summary.quotaWindows[1].remaining, 62, accuracy: 0.1)
    }
}
