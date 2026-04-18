import Foundation

// MARK: - API Endpoints Catalogue
//
// All API paths live here. Use these in call sites instead of raw strings.
// Example:
//   let conversations = try await client.request(API.conversations, responseType: [Conversation].self)

enum API {

    // MARK: Conversations
    static var conversations: Endpoint {
        Endpoint(path: "/conversations")
    }

    static func conversation(id: String) -> Endpoint {
        Endpoint(path: "/conversations/\(id)")
    }

    static func createConversation(title: String) -> Endpoint {
        Endpoint(path: "/conversations", method: .post, body: ["title": title])
    }

    static func deleteConversation(id: String) -> Endpoint {
        Endpoint(path: "/conversations/\(id)", method: .delete)
    }

    // MARK: Messages
    static func messages(conversationId: String) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)/messages")
    }

    static func sendMessage(conversationId: String, content: String) -> Endpoint {
        Endpoint(
            path: "/conversations/\(conversationId)/messages",
            method: .post,
            body: ["content": content]
        )
    }

    // MARK: Auth
    static func login(email: String, password: String) -> Endpoint {
        Endpoint(
            path: "/auth/login",
            method: .post,
            body: ["email": email, "password": password]
        )
    }

    static var logout: Endpoint {
        Endpoint(path: "/auth/logout", method: .post)
    }

    static var me: Endpoint {
        Endpoint(path: "/auth/me")
    }

    // MARK: Settings
    static func updateProfile(name: String) -> Endpoint {
        Endpoint(path: "/users/me", method: .patch, body: ["name": name])
    }
}
