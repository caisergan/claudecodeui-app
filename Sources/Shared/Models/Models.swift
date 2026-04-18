import Foundation

// MARK: - User

struct User: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var email: String
    var avatarURL: URL?

    init(id: String = UUID().uuidString, name: String, email: String, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
    }
}

// MARK: - Message

struct Message: Identifiable, Codable, Equatable {
    let id: String
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(id: String = UUID().uuidString, role: MessageRole, content: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        messages: [Message] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed
    case noData
    case unauthorized
    case serverError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .requestFailed(let code): return "Request failed with status \(code)."
        case .decodingFailed: return "Failed to decode the response."
        case .noData: return "No data received."
        case .unauthorized: return "Unauthorized. Please log in again."
        case .serverError(let msg): return "Server error: \(msg)"
        case .unknown(let err): return err.localizedDescription
        }
    }
}
