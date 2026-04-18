import Foundation

// MARK: - MockURLProtocol
//
// Intercepts URLSession requests in tests so no real network calls are made.
// Usage in tests:
//   let session = URLSession.mock(data: jsonData, statusCode: 200)
//   let client  = APIClient(baseURL: url, session: session)

final class MockURLProtocol: URLProtocol {
    // Set these before each test
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - URLSession convenience

extension URLSession {
    /// Returns a URLSession that intercepts all requests via MockURLProtocol.
    static func mock(data: Data, statusCode: Int = 200, url: URL? = nil) -> URLSession {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: url ?? request.url ?? URL(string: "https://mock.test")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
