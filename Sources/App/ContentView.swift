import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("colorSchemePreference") private var colorSchemePreference: ColorSchemePreference = .system

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            Group {
                if appState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(colorSchemePreference.colorScheme)
        // Animate the auth ↔ main transition
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
        .task {
            await appState.restoreSession()
        }
    }
}

// MARK: - MainTabView

private struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview("Authenticated") {
    ContentView()
        .environmentObject({
            let s = AppState()
            s.isAuthenticated = true
            return s
        }())
}

#Preview("Unauthenticated") {
    ContentView()
        .environmentObject(AppState())
}
