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
    let bodyKeyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
    let queryItems: [URLQueryItem]
    let extraHeaders: [String: String]
    let authMode: AuthMode

    init(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        bodyKeyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase,
        queryItems: [URLQueryItem] = [],
        extraHeaders: [String: String] = [:],
        authMode: AuthMode = .jwt
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.bodyKeyEncodingStrategy = bodyKeyEncodingStrategy
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

private struct APIErrorPayload: Decodable {
    let error: String?
    let message: String?
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient(baseURLProvider: { AppConfig.apiBaseURL })
    static let serverShared = APIClient(baseURLProvider: { AppConfig.serverBaseURL })

    private let session: URLSession
    private let baseURLProvider: () -> URL
    private let decoder = JSONDecoder()

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.baseURLProvider = { baseURL }
        self.session = session
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    init(baseURLProvider: @escaping () -> URL, session: URLSession = .shared) {
        self.baseURLProvider = baseURLProvider
        self.session = session
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    var resolvedBaseURL: URL {
        baseURLProvider()
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
            if let compatibilityError = compatibilityError(
                for: endpoint,
                data: data,
                response: httpResponse
            ) {
                throw compatibilityError
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                if let compatibilityError = compatibilityError(
                    for: endpoint,
                    data: data,
                    response: httpResponse
                ) {
                    throw compatibilityError
                }
                throw APIError.decodingFailed
            }
        default:
            throw error(for: endpoint, data: data, response: httpResponse)
        }
    }

    func requestEmpty(_ endpoint: Endpoint) async throws {
        let urlRequest = try buildRequest(for: endpoint)
        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else { return }

        if !(200...299).contains(httpResponse.statusCode) {
            throw error(for: endpoint, data: Data(), response: httpResponse)
        }
    }

    // MARK: - Helpers

    func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        let baseURL = baseURLProvider()

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
            if let key = AppConfig.resolvedAgentAPIKey {
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
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = endpoint.bodyKeyEncodingStrategy
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func error(
        for endpoint: Endpoint,
        data: Data,
        response: HTTPURLResponse
    ) -> APIError {
        if response.statusCode == 401, endpoint.authMode == .jwt {
            return .unauthorized
        }

        if let payload = try? decoder.decode(APIErrorPayload.self, from: data),
           let message = payload.error ?? payload.message,
           !message.isBlank {
            return .serverError(message)
        }

        if response.statusCode == 401 {
            return .unauthorized
        }

        return .requestFailed(statusCode: response.statusCode)
    }

    private func compatibilityError(
        for endpoint: Endpoint,
        data: Data,
        response: HTTPURLResponse
    ) -> APIError? {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let bodyPreview = String(data: data.prefix(256), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        let receivedHTML = contentType.contains("text/html")
            || bodyPreview.hasPrefix("<!doctype html")
            || bodyPreview.hasPrefix("<html")

        guard receivedHTML else {
            return nil
        }

        return .serverError(
            """
            Expected JSON from \(endpoint.path) but received HTML. \
            This base URL points to a frontend site or an incompatible backend.
            """
        )
    }
}
