import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var conversationTitle: String = "New Chat"

    var conversation: Conversation = Conversation()

    private let provider: AIProvider
    private let client: APIClient
    private let storage: UserDefaultsStorage
    private var agentSessionContext: AgentSessionContext?

    init(
        provider: AIProvider = .claude,
        client: APIClient = .shared,
        storage: UserDefaultsStorage = .shared
    ) {
        self.provider = provider
        self.client = client
        self.storage = storage
        restoreCachedAgentContext()
    }

    func loadChatContext() async {
        guard !AppConfig.disableAuthentication,
              let context = resolveAgentSessionContext() else {
            return
        }

        if context.messages.isNotEmpty {
            messages = context.messages
        }

        do {
            try await refreshAgentMessages(using: context)
        } catch {
            AppLogger.network.warning("Agent message refresh failed: \(error.localizedDescription)")
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isBlank else { return }

        // Append user message immediately
        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""

        if AppConfig.disableAuthentication {
            messages.append(
                Message(
                    role: .assistant,
                    content: "Preview mode is active. Connect app auth to send live messages."
                )
            )
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            if let context = resolveAgentSessionContext() {
                try await sendAgentMessage(text, using: context)
            } else {
                let response = try await client.request(
                    API.sendMessage(conversationId: conversation.id, content: text),
                    responseType: Message.self
                )
                messages.append(response)
            }
        } catch {
            // On error, append a system error message
            let errorMsg = Message(
                role: .system,
                content: "⚠️ \(error.localizedDescription)"
            )
            messages.append(errorMsg)
        }
    }

    func clearMessages() {
        messages = []
    }

    private func sendAgentMessage(
        _ text: String,
        using context: AgentSessionContext
    ) async throws {
        let projectPath = context.projectPath ?? AppConfig.defaultProjectPath
        let response = try await client.request(
            API.agent(
                body: WarmupRequestPayload(
                    message: text,
                    provider: provider,
                    sessionId: context.sessionId,
                    projectPath: projectPath
                )
            ),
            responseType: WarmupResponse.self
        )

        let effectiveSessionId = response.sessionId?.isBlank == false
            ? response.sessionId!
            : context.sessionId
        let effectiveProjectPath = response.projectPath?.isBlank == false
            ? response.projectPath
            : projectPath
        let assistantMessages = response.messages.compactMap { $0.asAppMessage() }

        if assistantMessages.isNotEmpty {
            messages.append(contentsOf: assistantMessages)
            persistAgentContext(
                AgentSessionContext(
                    sessionId: effectiveSessionId,
                    projectPath: effectiveProjectPath,
                    messages: messages
                )
            )
            return
        }

        try await refreshAgentMessages(
            using: AgentSessionContext(
                sessionId: effectiveSessionId,
                projectPath: effectiveProjectPath,
                messages: messages
            )
        )
    }

    private func refreshAgentMessages(using context: AgentSessionContext) async throws {
        let response = try await client.request(
            API.agentMessages(
                sessionId: context.sessionId,
                provider: provider.rawValue,
                projectPath: context.projectPath
            ),
            responseType: AgentMessagesResponse.self
        )

        let refreshedMessages = response.messages.compactMap { $0.asAppMessage() }
        guard refreshedMessages.isNotEmpty else {
            persistAgentContext(context)
            return
        }

        persistAgentContext(
            AgentSessionContext(
                sessionId: context.sessionId,
                projectPath: context.projectPath,
                messages: refreshedMessages
            )
        )
    }

    private func restoreCachedAgentContext() {
        guard let context = storage.agentSessionContext(for: provider) else {
            return
        }

        persistAgentContext(context)
    }

    private func resolveAgentSessionContext() -> AgentSessionContext? {
        if let agentSessionContext {
            return agentSessionContext
        }

        guard let sessionId = storage.warmupSessionId(for: provider), !sessionId.isBlank else {
            return nil
        }

        let fallbackContext = AgentSessionContext(
            sessionId: sessionId,
            projectPath: storage.agentSessionContext(for: provider)?.projectPath ?? AppConfig.defaultProjectPath,
            messages: storage.agentSessionContext(for: provider)?.messages ?? []
        )
        persistAgentContext(fallbackContext)
        return fallbackContext
    }

    private func persistAgentContext(_ context: AgentSessionContext) {
        agentSessionContext = context
        storage.setAgentSessionContext(context, for: provider)
        conversationTitle = provider.displayName

        if context.messages.isNotEmpty {
            messages = context.messages
        }
    }
}
