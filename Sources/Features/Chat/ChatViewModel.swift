import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var conversationTitle: String = "New Chat"

    var conversation: Conversation = Conversation()

    private let client = APIClient.shared

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
            let response = try await client.request(
                Endpoint(
                    path: "/conversations/\(conversation.id)/messages",
                    method: .post,
                    body: ["content": text]
                ),
                responseType: Message.self
            )
            messages.append(response)
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
}
