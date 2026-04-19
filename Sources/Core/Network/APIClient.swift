import Foundation

// MARK: - Auth Mode

enum AuthMode {
    /// Bearer token from Keychain (.authToken)
    case jwt
    /// External API key from Keychain (.agentAPIKey)
    case apiKey
    /// No auth header
    case none
}

// MARK: - Endpoint

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]
    let extraHeaders: [String: String]
    let authMode: AuthMode

    init(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem] = [],
        extraHeaders: [String: String] = [:],
        authMode: AuthMode = .jwt
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.extraHeaders = extraHeaders
        self.authMode = authMode
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        let urlRequest = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed
            }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    func requestEmpty(_ endpoint: Endpoint) async throws {
        let urlRequest = try buildRequest(for: endpoint)
        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else { return }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        if !(200...299).contains(httpResponse.statusCode) {
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Helpers

    func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let baseComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }

        // Combine base path with endpoint path
        var components = baseComponents
        let combinedPath = baseComponents.path.appending(endpoint.path)
        components.path = combinedPath

        // Query items
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth
        switch endpoint.authMode {
        case .jwt:
            if let token = KeychainHelper.shared.read(key: .authToken) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .apiKey:
            if let key = KeychainHelper.shared.read(key: .agentAPIKey) {
                request.setValue(key, forHTTPHeaderField: "x-api-key")
            }
        case .none:
            break
        }

        // Extra headers
        for (field, value) in endpoint.extraHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }
}
