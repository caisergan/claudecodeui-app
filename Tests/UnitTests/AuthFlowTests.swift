import XCTest
@testable import ClaudeCodeUI

@MainActor
final class AuthFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainHelper.shared.clearAll()
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        KeychainHelper.shared.clearAll()
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testLoginViewModelStoresJWTAndMapsBackendUser() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/api/auth/login")

            let body = try Self.jsonBody(from: request)
            XCTAssertEqual(body["username"] as? String, "alice")
            XCTAssertEqual(body["password"] as? String, "secret123")

            return try Self.jsonResponse(
                [
                    "success": true,
                    "token": "jwt-token-123",
                    "user": [
                        "id": 7,
                        "username": "alice",
                    ],
                ],
                for: request
            )
        }

        let client = APIClient(baseURL: URL(string: "https://mock.test/api")!, session: session)
        let viewModel = LoginViewModel(client: client)
        let appState = AppState(client: client)
        viewModel.username = "alice"
        viewModel.password = "secret123"

        await viewModel.login(appState: appState)

        XCTAssertEqual(KeychainHelper.shared.read(key: .authToken), "jwt-token-123")
        XCTAssertEqual(KeychainHelper.shared.read(key: .userId), "7")
        XCTAssertEqual(appState.currentUser, User(id: "7", name: "alice", email: "alice"))
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertFalse(viewModel.showError)
    }

    func testRestoreSessionUsesCurrentUserEnvelope() async throws {
        KeychainHelper.shared.save("jwt-token-123", key: .authToken)

        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/api/auth/user")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token-123")

            return try Self.jsonResponse(
                [
                    "user": [
                        "id": 11,
                        "username": "dev-user",
                    ],
                ],
                for: request
            )
        }

        let client = APIClient(baseURL: URL(string: "https://mock.test/api")!, session: session)
        let appState = AppState(client: client)

        await appState.restoreSession()

        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertEqual(appState.currentUser, User(id: "11", name: "dev-user", email: "dev-user"))
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
