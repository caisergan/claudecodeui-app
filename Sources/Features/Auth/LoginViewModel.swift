import Foundation

// MARK: - Login Response

private struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: User
}

// MARK: - LoginViewModel

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var showForgotPassword: Bool = false
    @Published var errorMessage: String? = nil

    private let client = APIClient.shared

    var isFormValid: Bool {
        !email.isBlank && !password.isBlank && email.contains("@")
    }

    func login(appState: AppState) async {
        guard isFormValid else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.request(
                API.login(email: email, password: password),
                responseType: LoginResponse.self
            )

            // Persist tokens
            KeychainHelper.shared.save(response.accessToken, key: .authToken)
            KeychainHelper.shared.save(response.refreshToken, key: .refreshToken)
            KeychainHelper.shared.save(response.user.id, key: .userId)

            // Update global state
            appState.currentUser = response.user
            appState.isAuthenticated = true

            AppLogger.auth.info("User signed in: \(response.user.id)")

        } catch {
            errorMessage = error.localizedDescription
            showError = true
            AppLogger.auth.error("Login failed: \(error)")
        }
    }
}
