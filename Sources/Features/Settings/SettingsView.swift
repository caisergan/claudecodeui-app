import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section("Profile") {
                    if let user = appState.currentUser {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(.indigo.gradient)
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Text(user.name.prefix(1).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Not signed in")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Providers
                Section("Providers") {
                    ForEach(AIProvider.allCases) { provider in
                        ProviderRow(
                            provider: provider,
                            preference: viewModel.preferences[provider] ?? .default,
                            onToggle: { enabled in
                                viewModel.toggleProvider(provider, isEnabled: enabled)
                            },
                            onModelChange: { model in
                                viewModel.updateWarmupModel(provider, model: model)
                            }
                        )
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.colorScheme) {
                        Text("System").tag(ColorSchemePreference.system)
                        Text("Light").tag(ColorSchemePreference.light)
                        Text("Dark").tag(ColorSchemePreference.dark)
                    }
                }

                // MARK: - About
                Section("About") {
                    LabeledContent("Version", value: viewModel.appVersion)
                    LabeledContent("Build", value: viewModel.buildNumber)
                    Link("Privacy Policy", destination: URL(string: "https://claudecodeui.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://claudecodeui.com/terms")!)
                }

                // MARK: - Danger Zone
                Section {
                    Button(role: .destructive) {
                        viewModel.showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                viewModel.loadProviderSettings()
            }
            .confirmationDialog(
                "Sign out of your account?",
                isPresented: $viewModel.showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut(appState: appState)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    let provider: AIProvider
    let preference: ProviderPreference
    let onToggle: (Bool) -> Void
    let onModelChange: (String) -> Void

    private var modelSelection: Binding<String> {
        Binding(
            get: { preference.warmupModel },
            set: { onModelChange($0) }
        )
    }

    private var supportedModels: [String] {
        provider.supportedWarmupModels
    }

    private var menuOptions: [String] {
        provider.warmupModelMenuOptions(including: preference.warmupModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(provider.displayName, isOn: Binding(
                get: { preference.isEnabled },
                set: { onToggle($0) }
            ))

            if preference.isEnabled {
                if supportedModels.isEmpty {
                    HStack {
                        Text("Model")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField(
                            "Default",
                            text: Binding(
                                get: { preference.warmupModel },
                                set: { onModelChange($0) }
                            )
                        )
                        .font(.subheadline)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                } else {
                    Picker("Model", selection: modelSelection) {
                        Text("Default").tag("")
                        ForEach(menuOptions, id: \.self) { model in
                            Text(modelRowTitle(for: model))
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func modelRowTitle(for model: String) -> String {
        guard model == preference.warmupModel, !supportedModels.contains(model) else {
            return model
        }
        return "\(model) (saved)"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
