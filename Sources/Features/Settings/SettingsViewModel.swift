import Foundation
import SwiftUI

enum ColorSchemePreference: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showSignOutConfirmation: Bool = false
    @AppStorage("colorSchemePreference") var colorScheme: ColorSchemePreference = .system

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    func signOut(appState: AppState) {
        KeychainHelper.shared.clearAll()
        appState.isAuthenticated = false
        appState.currentUser = nil
    }
}
