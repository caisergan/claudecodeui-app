import XCTest
@testable import ClaudeCodeUI

@MainActor
final class HomeViewModelTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var storage: UserDefaultsStorage!
    private let suiteName = "HomeViewModelTests"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
        storage = UserDefaultsStorage(store: testDefaults)
        KeychainHelper.shared.save("test-agent-key", key: .agentAPIKey)
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        KeychainHelper.shared.delete(key: .agentAPIKey)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testWarmupStoresProviderSpecificSessionId() async throws {
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                return try Self.jsonResponse(
                    ["status": "ok", "timestamp": "2026-04-19T00:00:00Z", "appInstallPath": "/tmp/project"],
                    for: request
                )
            case "/api/agent":
                return try Self.jsonResponse(
                    ["success": true, "sessionId": "codex-session-1"],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)

        await viewModel.warmupProvider(.codex)

        XCTAssertEqual(storage.warmupSessionId(for: .codex), "codex-session-1")
        XCTAssertNil(storage.warmupSessionId(for: .claude))
    }

    func testWarmupStoresLastSuccessfulTimestampPerProvider() async throws {
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                return try Self.jsonResponse(
                    ["status": "ok", "timestamp": "2026-04-19T00:00:00Z", "appInstallPath": "/tmp/project"],
                    for: request
                )
            case "/api/agent":
                return try Self.jsonResponse(
                    ["success": true, "sessionId": "codex-session-1"],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)
        let startedAt = Date()

        await viewModel.warmupProvider(.codex)

        let storedDate = try XCTUnwrap(storage.lastSuccessfulWarmupDate(for: .codex))
        let viewModelDate = try XCTUnwrap(viewModel.lastSuccessfulWarmupDates[.codex])
        XCTAssertGreaterThanOrEqual(storedDate.timeIntervalSince1970, startedAt.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(storedDate.timeIntervalSinceNow, 1)
        XCTAssertEqual(
            viewModelDate.timeIntervalSince1970,
            storedDate.timeIntervalSince1970,
            accuracy: 0.01
        )
        XCTAssertNil(storage.lastSuccessfulWarmupDate(for: .claude))
    }

    func testWarmupReusesStoredSessionForSameProvider() async throws {
        storage.setWarmupSessionId("codex-session-existing", for: .codex)

        var capturedBody: [String: Any]?
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                return try Self.jsonResponse(
                    ["status": "ok", "timestamp": "2026-04-19T00:00:00Z", "appInstallPath": "/tmp/project"],
                    for: request
                )
            case "/api/agent":
                capturedBody = try Self.jsonBody(from: request)
                return try Self.jsonResponse(
                    ["success": true, "sessionId": "codex-session-existing"],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)

        await viewModel.warmupProvider(.codex)

        XCTAssertEqual(capturedBody?["provider"] as? String, "codex")
        XCTAssertEqual(capturedBody?["sessionId"] as? String, "codex-session-existing")
    }

    func testWarmupDoesNotReuseAnotherProvidersSession() async throws {
        storage.setWarmupSessionId("codex-session-existing", for: .codex)

        var capturedBody: [String: Any]?
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                return try Self.jsonResponse(
                    ["status": "ok", "timestamp": "2026-04-19T00:00:00Z", "appInstallPath": "/tmp/project"],
                    for: request
                )
            case "/api/agent":
                capturedBody = try Self.jsonBody(from: request)
                return try Self.jsonResponse(
                    ["success": true, "sessionId": "claude-session-new"],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)

        await viewModel.warmupProvider(.claude)

        XCTAssertEqual(capturedBody?["provider"] as? String, "claude")
        XCTAssertNil(capturedBody?["sessionId"])
        XCTAssertEqual(storage.warmupSessionId(for: .claude), "claude-session-new")
        XCTAssertEqual(storage.warmupSessionId(for: .codex), "codex-session-existing")
    }

    func testWarmupSurfacesHealthCheckFailure() async {
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                throw URLError(.cannotConnectToHost)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)

        await viewModel.warmupProvider(.codex)

        guard case .failure(let message) = viewModel.warmupStates[.codex] else {
            return XCTFail("Expected codex warmup to fail")
        }

        XCTAssertTrue(
            message.hasPrefix("Warmup could not reach the backend health check."),
            "Unexpected failure message: \(message)"
        )
        XCTAssertEqual(viewModel.errorMessage, "Codex warmup failed: \(message)")
    }

    func testWarmupShowsActionableProjectPathMessageWhenHealthHasNoInstallPath() async throws {
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                return try Self.jsonResponse(
                    ["status": "ok", "timestamp": "2026-04-19T00:00:00Z"],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)

        await viewModel.warmupProvider(.codex)

        guard case .failure(let message) = viewModel.warmupStates[.codex] else {
            return XCTFail("Expected codex warmup to fail")
        }

        XCTAssertEqual(
            message,
            """
            Warmup could not resolve the server project path automatically. \
            Set warmup_project_path in .env or ensure /health returns appInstallPath.
            """
        )
        XCTAssertEqual(viewModel.errorMessage, "Codex warmup failed: \(message)")
    }

    func testLoadProviderSettingsRestoresStoredLastSuccessfulWarmupDate() {
        let storedDate = Date(timeIntervalSince1970: 1_713_571_200)
        storage.setLastSuccessfulWarmupDate(storedDate, for: .gemini)

        let viewModel = HomeViewModel(storage: storage)
        viewModel.loadProviderSettings()

        XCTAssertEqual(viewModel.lastSuccessfulWarmupDates[.gemini], storedDate)
        XCTAssertNil(viewModel.lastSuccessfulWarmupDates[.codex])
    }

    func testWarmupFailureKeepsPreviousSuccessfulTimestamp() async throws {
        let existingDate = Date(timeIntervalSince1970: 1_713_571_200)
        storage.setLastSuccessfulWarmupDate(existingDate, for: .codex)

        let session = makeMockSession { request in
            switch request.url?.path {
            case "/health":
                return try Self.jsonResponse(
                    ["status": "ok", "timestamp": "2026-04-19T00:00:00Z", "appInstallPath": "/tmp/project"],
                    for: request
                )
            case "/api/agent":
                throw URLError(.badServerResponse)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)
        viewModel.loadProviderSettings()

        await viewModel.warmupProvider(.codex)

        XCTAssertEqual(storage.lastSuccessfulWarmupDate(for: .codex), existingDate)
        XCTAssertEqual(viewModel.lastSuccessfulWarmupDates[.codex], existingDate)
    }

    func testUsageProvidersExcludeClaudeAndRefreshRequestsOnlyNonClaudeProviders() async throws {
        var requestedProviders: [String] = []

        let session = makeMockSession { request in
            switch request.url?.path {
            case "/api/usage-limits":
                let components = try XCTUnwrap(
                    URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
                )
                let provider = try XCTUnwrap(
                    components.queryItems?.first(where: { $0.name == "provider" })?.value
                )
                requestedProviders.append(provider)

                return try Self.jsonResponse(
                    [
                        "success": true,
                        "checked_at": "2026-04-20T00:00:00Z",
                        "providers": [
                            provider: [
                                "provider": provider,
                                "installed": true,
                                "authenticated": true,
                                "state": provider == "codex" ? "available" : "unsupported",
                                "message": provider == "codex"
                                    ? "Codex usage data was fetched successfully."
                                    : "\(provider.capitalized) usage detection is not supported yet.",
                                "limits": provider == "codex"
                                    ? [
                                        "primary": [
                                            "remaining_percent": 80,
                                            "limit_window_seconds": 18_000,
                                        ],
                                    ]
                                    : [:],
                            ],
                        ],
                    ],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)
        viewModel.loadProviderSettings()

        XCTAssertEqual(viewModel.usageProviders, [.codex, .cursor, .gemini])

        await viewModel.refreshUsage(forceRefresh: true)

        XCTAssertEqual(requestedProviders, ["codex", "cursor", "gemini"])
        XCTAssertEqual(viewModel.usageSummaries.map(\.provider), [.codex, .cursor, .gemini])
    }

    func testRefreshUsageUsesLiveEndpointWhenAvailableInPreviewMode() async throws {
        guard AppConfig.disableAuthentication else {
            throw XCTSkip("Preview-mode assertions only apply when auth bypass is enabled.")
        }

        var requestedPaths: [String] = []
        let session = makeMockSession { request in
            requestedPaths.append(request.url?.path ?? "")

            switch request.url?.path {
            case "/api/usage-limits":
                return try Self.jsonResponse(
                    [
                        "success": true,
                        "checked_at": "2026-04-19T00:00:00Z",
                        "providers": [
                            "codex": [
                                "provider": "codex",
                                "installed": true,
                                "authenticated": true,
                                "account": "dev@example.com",
                                "plan_type": "ChatGPT Plus",
                                "state": "available",
                                "limit_reached": false,
                                "reset_at": "2030-04-19T05:00:00Z",
                                "supports_remaining_quota": true,
                                "limits": [
                                    "primary": [
                                        "remaining_percent": 80,
                                        "limit_window_seconds": 18_000,
                                    ],
                                    "secondary": [
                                        "remaining_percent": 45,
                                        "limit_window_seconds": 604_800,
                                    ],
                                ],
                            ],
                        ],
                    ],
                    for: request
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)
        viewModel.loadProviderSettings()

        await viewModel.refreshUsage()

        XCTAssertEqual(requestedPaths, ["/api/usage-limits"])

        let codexSummary = try XCTUnwrap(
            viewModel.usageSummaries.first(where: { $0.provider == .codex })
        )
        XCTAssertEqual(codexSummary.status, .ready)
        XCTAssertEqual(codexSummary.quotaWindows.count, 2)
        XCTAssertEqual(codexSummary.quotaWindows[0].label, "5h")
        XCTAssertEqual(codexSummary.quotaWindows[0].remaining, 80)
        XCTAssertEqual(codexSummary.quotaWindows[1].label, "7d")
        XCTAssertEqual(codexSummary.quotaWindows[1].remaining, 45)
        XCTAssertTrue(codexSummary.metadata?.contains("ChatGPT Plus") == true)
        XCTAssertTrue(codexSummary.metadata?.contains("dev@example.com") == true)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRefreshUsageFallsBackToPreviewWhenLiveRequestFailsInPreviewMode() async throws {
        guard AppConfig.disableAuthentication else {
            throw XCTSkip("Preview-mode assertions only apply when auth bypass is enabled.")
        }

        let session = makeMockSession { request in
            switch request.url?.path {
            case "/api/usage-limits":
                throw URLError(.cannotConnectToHost)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let viewModel = makeViewModel(session: session)
        viewModel.loadProviderSettings()

        await viewModel.refreshUsage()

        let claudeSummary = try XCTUnwrap(
            viewModel.usageSummaries.first(where: { $0.provider == .claude })
        )
        XCTAssertEqual(claudeSummary.status, .preview)
        XCTAssertEqual(claudeSummary.statusMessage, "Preview mode active")
        XCTAssertTrue(claudeSummary.quotaWindows.isEmpty)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    private func makeViewModel(session: URLSession) -> HomeViewModel {
        HomeViewModel(
            client: APIClient(baseURL: URL(string: "https://mock.test/api")!, session: session),
            serverClient: APIClient(baseURL: URL(string: "https://mock.test")!, session: session),
            storage: storage
        )
    }

    private func makeMockSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        MockURLProtocol.requestHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func jsonResponse(
        _ object: [String: Any],
        for request: URLRequest
    ) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: object)
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, data)
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(bodyData(from: request))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }

        return data.isEmpty ? nil : data
    }
}
