import Foundation

// MARK: - API Endpoints Catalogue
//
// All API paths live here. Use these in call sites instead of raw strings.
// Example:
//   let conversations = try await client.request(API.conversations, responseType: [Conversation].self)

enum API {

    // MARK: Server Root
    static var health: Endpoint {
        Endpoint(path: "/health", authMode: .none)
    }

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
            body: ["email": email, "password": password],
            authMode: .none
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

    // MARK: Usage & Readiness
    static func usageLimits(provider: String? = nil, refresh: Bool = false) -> Endpoint {
        var items: [URLQueryItem] = []
        if let provider { items.append(.init(name: "provider", value: provider)) }
        if refresh { items.append(.init(name: "refresh", value: "true")) }
        return Endpoint(path: "/usage-limits", queryItems: items)
    }

    static func cliStatus(provider: String) -> Endpoint {
        Endpoint(path: "/cli/\(provider)/status")
    }

    // MARK: Agent (external API key auth)
    static func agent(body: WarmupRequestPayload) -> Endpoint {
        Endpoint(
            path: "/agent",
            method: .post,
            body: body,
            bodyKeyEncodingStrategy: .useDefaultKeys,
            authMode: .apiKey
        )
    }
}
