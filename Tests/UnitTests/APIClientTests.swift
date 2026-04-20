import XCTest
@testable import ClaudeCodeUI

final class APIClientTests: XCTestCase {

    private var baseURL: URL!

    override func setUp() {
        super.setUp()
        baseURL = URL(string: "https://mock.test/api")!
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Successful decode

    func testRequestDecodesResponseSuccessfully() async throws {
        let user = User(id: "u1", name: "Alice", email: "alice@test.com")
        let data = try JSONEncoder().encode(user)
        let session = URLSession.mock(data: data, statusCode: 200)
        let client = APIClient(baseURL: baseURL, session: session)

        let result = try await client.request(
            Endpoint(path: "/users/me"),
            responseType: User.self
        )

        XCTAssertEqual(result.id, "u1")
        XCTAssertEqual(result.name, "Alice")
    }

    // MARK: - 401 → .unauthorized

    func testRequestThrowsUnauthorizedOn401() async {
        let session = URLSession.mock(data: Data(), statusCode: 401)
        let client = APIClient(baseURL: baseURL, session: session)

        do {
            _ = try await client.request(
                Endpoint(path: "/users/me"),
                responseType: User.self
            )
            XCTFail("Expected APIError.unauthorized")
        } catch APIError.unauthorized {
            // ✓
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - 500 → .requestFailed

    func testRequestThrowsRequestFailedOnServerError() async {
        let session = URLSession.mock(data: Data(), statusCode: 500)
        let client = APIClient(baseURL: baseURL, session: session)

        do {
            _ = try await client.request(
                Endpoint(path: "/conversations"),
                responseType: [Conversation].self
            )
            XCTFail("Expected APIError.requestFailed")
        } catch APIError.requestFailed(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Bad JSON → .decodingFailed

    func testRequestThrowsDecodingFailedOnGarbledJSON() async {
        let garbage = Data("not json at all!!!".utf8)
        let session = URLSession.mock(data: garbage, statusCode: 200)
        let client = APIClient(baseURL: baseURL, session: session)

        do {
            _ = try await client.request(
                Endpoint(path: "/users/me"),
                responseType: User.self
            )
            XCTFail("Expected APIError.decodingFailed")
        } catch APIError.decodingFailed {
            // ✓
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequestThrowsCompatibilityErrorWhenHTMLIsReturnedFromAPIEndpoint() async {
        MockURLProtocol.requestHandler = { request in
            let html = Data("<!doctype html><html><body>App shell</body></html>".utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=UTF-8"]
            )!
            return (response, html)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = APIClient(baseURL: baseURL, session: session)

        do {
            _ = try await client.request(
                Endpoint(path: "/usage-limits"),
                responseType: UsageLimitsResponse.self
            )
            XCTFail("Expected APIError.serverError")
        } catch APIError.serverError(let message) {
            XCTAssertTrue(message.contains("/usage-limits"))
            XCTAssertTrue(message.contains("received HTML"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Encode array response

    func testRequestDecodesArraySuccessfully() async throws {
        let conversations = [Conversation(title: "First"), Conversation(title: "Second")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conversations)
        let session = URLSession.mock(data: data, statusCode: 200)
        let client = APIClient(baseURL: baseURL, session: session)

        let result = try await client.request(
            Endpoint(path: "/conversations"),
            responseType: [Conversation].self
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].title, "First")
    }

    // MARK: - POST method is sent correctly

    func testPostMethodIsSetOnRequest() async throws {
        var capturedMethod: String?
        MockURLProtocol.requestHandler = { request in
            capturedMethod = request.httpMethod
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Message(role: .assistant, content: "Hi"))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = APIClient(baseURL: baseURL, session: session)

        _ = try await client.request(
            Endpoint(path: "/messages", method: .post, body: ["content": "Hello"]),
            responseType: Message.self
        )

        XCTAssertEqual(capturedMethod, "POST")
    }

    // MARK: - Query items are encoded

    func testQueryItemsAreEncodedInURL() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let endpoint = API.usageLimits(provider: "claude", refresh: true)
        let request = try client.buildRequest(for: endpoint)

        let url = request.url!.absoluteString
        XCTAssertTrue(url.contains("provider=claude"), "URL should contain provider query: \(url)")
        XCTAssertTrue(url.contains("refresh=true"), "URL should contain refresh query: \(url)")
    }

    func testEndpointDefaultsToJWTAuth() {
        let endpoint = Endpoint(path: "/protected")

        switch endpoint.authMode {
        case .jwt:
            break
        default:
            XCTFail("App endpoints should default to JWT auth")
        }
    }

    func testAPIKeyRequestsPreferSettingsKeyOverEnvValue() throws {
        let resolved = AppConfig.preferredAgentAPIKey(
            envValue: "env-key",
            keychainValue: "keychain-key"
        )

        XCTAssertEqual(resolved, "keychain-key")
    }

    func testBuildRequestUsesLatestBaseURLFromProvider() throws {
        var currentBaseURL = URL(string: "https://initial.test/api")!
        let client = APIClient(baseURLProvider: { currentBaseURL }, session: .shared)

        var request = try client.buildRequest(for: Endpoint(path: "/health", authMode: .none))
        XCTAssertEqual(request.url?.absoluteString, "https://initial.test/api/health")

        currentBaseURL = URL(string: "https://updated.test/api")!
        request = try client.buildRequest(for: Endpoint(path: "/health", authMode: .none))
        XCTAssertEqual(request.url?.absoluteString, "https://updated.test/api/health")
    }

    func testAPIKey401ReturnsServerErrorMessage() async {
        let payload = #"{"error":"Invalid or inactive API key"}"#.data(using: .utf8)!
        let session = URLSession.mock(data: payload, statusCode: 401)
        let client = APIClient(baseURL: baseURL, session: session)

        do {
            _ = try await client.request(
                Endpoint(path: "/agent", authMode: .apiKey),
                responseType: WarmupResponse.self
            )
            XCTFail("Expected APIError.serverError")
        } catch APIError.serverError(let message) {
            XCTAssertEqual(message, "Invalid or inactive API key")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - CLI status path

    func testCLIStatusEndpointPath() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let endpoint = API.cliStatus(provider: "gemini")
        let request = try client.buildRequest(for: endpoint)

        let url = request.url!.absoluteString
        XCTAssertTrue(url.contains("/cli/gemini/status"), "URL should contain CLI status path: \(url)")
    }

    func testLoginEndpointUsesUsernamePayload() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let endpoint = API.login(username: "alice", password: "secret123")
        let request = try client.buildRequest(for: endpoint)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.path, "/api/auth/login")
        XCTAssertEqual(json["username"], "alice")
        XCTAssertEqual(json["password"], "secret123")
        XCTAssertNil(json["email"])
    }

    func testCurrentUserEndpointPathUsesBackendRoute() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let request = try client.buildRequest(for: API.me)

        XCTAssertEqual(request.url?.path, "/api/auth/user")
    }

    // MARK: - Agent endpoint uses apiKey auth mode

    func testAgentEndpointUsesAPIKeyAuth() throws {
        let payload = WarmupRequestPayload(provider: .claude, projectPath: "/tmp/test")
        let endpoint = API.agent(body: payload)

        // Verify auth mode is apiKey (not jwt)
        switch endpoint.authMode {
        case .apiKey:
            break // expected
        default:
            XCTFail("Agent endpoint should use .apiKey auth mode")
        }
    }

    // MARK: - Agent request body shape

    func testAgentRequestBodyContainsExpectedFields() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let endpoint = API.agent(body: WarmupRequestPayload(
            provider: .cursor,
            model: "gpt-4",
            sessionId: "sess-123",
            projectPath: "/projects/test"
        ))
        let request = try client.buildRequest(for: endpoint)
        let data = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["message"] as? String, "ping")
        XCTAssertEqual(json["provider"] as? String, "cursor")
        XCTAssertEqual(json["model"] as? String, "gpt-4")
        XCTAssertEqual(json["sessionId"] as? String, "sess-123")
        XCTAssertEqual(json["projectPath"] as? String, "/projects/test")
        XCTAssertEqual(json["stream"] as? Bool, false)
    }

    // MARK: - No auth header for .none mode

    func testNoAuthHeaderForNoneMode() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let endpoint = Endpoint(path: "/public", authMode: .none)
        let request = try client.buildRequest(for: endpoint)

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
    }

    // MARK: - Extra headers are applied

    func testExtraHeadersAreApplied() throws {
        let client = APIClient(baseURL: baseURL, session: .shared)
        let endpoint = Endpoint(
            path: "/test",
            extraHeaders: ["X-Custom": "hello"]
        )
        let request = try client.buildRequest(for: endpoint)

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "hello")
    }
}
