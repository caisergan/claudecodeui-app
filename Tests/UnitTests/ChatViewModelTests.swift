import XCTest
@testable import ClaudeCodeUI

@MainActor
final class ChatViewModelTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var storage: UserDefaultsStorage!
    private let suiteName = "ChatViewModelTests"

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

    func testLoadChatContextRefreshesStoredClaudeWarmupMessages() async throws {
        storage.setAgentSessionContext(
            AgentSessionContext(
                sessionId: "claude-session-1",
                projectPath: "/tmp/project",
                messages: [Message(role: .assistant, content: "Cached placeholder")]
            ),
            for: .claude
        )

        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/api/agent/sessions/claude-session-1/messages")

            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            )
            XCTAssertEqual(
                components.queryItems?.first(where: { $0.name == "provider" })?.value,
                "claude"
            )
            XCTAssertEqual(
                components.queryItems?.first(where: { $0.name == "projectPath" })?.value,
                "/tmp/project"
            )

            return try Self.jsonResponse(
                [
                    "messages": [
                        ["role": "assistant", "content": "Claude warmup ready"],
                    ],
                ],
                for: request
            )
        }

        let viewModel = makeViewModel(session: session)
        XCTAssertEqual(viewModel.messages.first?.content, "Cached placeholder")

        await viewModel.loadChatContext()

        XCTAssertEqual(viewModel.conversationTitle, "Claude")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .assistant)
        XCTAssertEqual(viewModel.messages.first?.content, "Claude warmup ready")
        XCTAssertEqual(storage.agentSessionContext(for: .claude)?.messages.first?.content, "Claude warmup ready")
    }

    func testSendMessageUsesClaudeAgentSessionWhenWarmupContextExists() async throws {
        storage.setAgentSessionContext(
            AgentSessionContext(
                sessionId: "claude-session-1",
                projectPath: "/tmp/project",
                messages: []
            ),
            for: .claude
        )

        var capturedBody: [String: Any]?
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/api/agent")
            capturedBody = try Self.jsonBody(from: request)
            return try Self.jsonResponse(
                [
                    "success": true,
                    "sessionId": "claude-session-1",
                    "projectPath": "/tmp/project",
                    "messages": [
                        ["role": "assistant", "content": "Handled by Claude"],
                    ],
                ],
                for: request
            )
        }

        let viewModel = makeViewModel(session: session)
        viewModel.inputText = "Please warm up"

        await viewModel.sendMessage()

        XCTAssertEqual(capturedBody?["message"] as? String, "Please warm up")
        XCTAssertEqual(capturedBody?["provider"] as? String, "claude")
        XCTAssertEqual(capturedBody?["sessionId"] as? String, "claude-session-1")
        XCTAssertEqual(capturedBody?["projectPath"] as? String, "/tmp/project")
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages.first?.role, .user)
        XCTAssertEqual(viewModel.messages.first?.content, "Please warm up")
        XCTAssertEqual(viewModel.messages.last?.role, .assistant)
        XCTAssertEqual(viewModel.messages.last?.content, "Handled by Claude")
        XCTAssertEqual(storage.agentSessionContext(for: .claude)?.messages.count, 2)
    }

    private func makeViewModel(session: URLSession) -> ChatViewModel {
        ChatViewModel(
            client: APIClient(baseURL: URL(string: "https://mock.test/api")!, session: session),
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
