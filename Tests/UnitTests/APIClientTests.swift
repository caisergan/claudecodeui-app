import XCTest
@testable import ClaudeCodeUI

final class APIClientTests: XCTestCase {

    private var baseURL: URL!

    override func setUp() {
        super.setUp()
        baseURL = URL(string: "https://mock.test/api/v1")!
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
}
