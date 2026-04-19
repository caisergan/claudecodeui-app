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
