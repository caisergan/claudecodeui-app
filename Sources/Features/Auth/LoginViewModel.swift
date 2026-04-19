import Foundation

// MARK: - LoginViewModel

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var showForgotPassword: Bool = false
    @Published var errorMessage: String? = nil

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    var isFormValid: Bool {
        !username.isBlank && !password.isBlank
    }

    func login(appState: AppState) async {
        guard isFormValid else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.request(
                API.login(username: username, password: password),
                responseType: AuthSessionResponse.self
            )

            // Persist JWT for protected app endpoints.
            KeychainHelper.shared.save(response.token, key: .authToken)
            KeychainHelper.shared.delete(key: .refreshToken)
            KeychainHelper.shared.save(response.user.id, key: .userId)

            // Update global state
            appState.currentUser = response.user.asAppUser()
            appState.isAuthenticated = true

            AppLogger.auth.info("User signed in: \(response.user.id)")

        } catch {
            errorMessage = error.localizedDescription
            showError = true
            AppLogger.auth.error("Login failed: \(error)")
        }
    }
}
