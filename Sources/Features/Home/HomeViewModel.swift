import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String? = nil

    private let client = APIClient.shared

    func loadConversations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await client.request(
                Endpoint(path: "/conversations"),
                responseType: [Conversation].self
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func createConversation() {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
    }
}
