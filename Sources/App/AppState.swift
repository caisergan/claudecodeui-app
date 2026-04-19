import Foundation
import Combine

/// Top-level app state shared across the entire app via @EnvironmentObject.
@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client

        if AppConfig.disableAuthentication {
            applyAuthBypassSession()
        }
    }

    // MARK: - Session Restore

    /// Called once on launch. Reads the saved token from Keychain and
    /// hydrates `currentUser` — silently signs out if the token is invalid.
    func restoreSession() async {
        if AppConfig.disableAuthentication {
            applyAuthBypassSession()
            return
        }

        guard KeychainHelper.shared.read(key: .authToken) != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.request(API.me, responseType: CurrentUserResponse.self)
            currentUser = response.user.asAppUser()
            isAuthenticated = true
            AppLogger.auth.info("Session restored for user: \(response.user.id)")
        } catch APIError.unauthorized {
            signOut()
        } catch {
            // Network error — keep user signed in optimistically
            AppLogger.auth.warning("Session restore failed (network?): \(error)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        if AppConfig.disableAuthentication {
            applyAuthBypassSession()
            return
        }

        KeychainHelper.shared.clearAll()
        currentUser = nil
        isAuthenticated = false
    }

    private func applyAuthBypassSession() {
        isAuthenticated = true
        currentUser = User(
            id: "debug-user",
            name: "Preview User",
            email: "preview@claudecodeui.local"
        )
        errorMessage = nil
    }
}
