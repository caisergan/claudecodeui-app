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

                // MARK: - Connection
                Section("Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Base URL")
                            .font(.subheadline)

                        TextField(
                            "Blank uses .env or the built-in default",
                            text: $viewModel.apiBaseURLOverrideText
                        )
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                        HStack {
                            Button("Save Base URL") {
                                guard viewModel.saveAPIBaseURLOverride() else { return }
                                Task {
                                    await viewModel.refreshRuntimeConfiguration(appState: appState)
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button("Use .env/default") {
                                Task {
                                    viewModel.clearAPIBaseURLOverride()
                                    await viewModel.refreshRuntimeConfiguration(appState: appState)
                                }
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.secondary)
                        }

                        LabeledContent("Active URL", value: viewModel.activeAPIBaseURL)
                            .font(.caption)
                        LabeledContent("Source", value: viewModel.apiBaseURLSourceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ClaudeCodeUI API Key")
                            .font(.subheadline)

                        SecureField(
                            "Blank uses .env when available",
                            text: $viewModel.agentAPIKeyText
                        )
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        HStack {
                            Button("Save API Key") {
                                viewModel.saveAgentAPIKey()
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button("Use .env") {
                                viewModel.clearAgentAPIKey()
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.secondary)
                        }

                        LabeledContent("Source", value: viewModel.agentAPIKeySourceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Warmup Project Path")
                            .font(.subheadline)

                        TextField(
                            "Blank uses .env or /health when available",
                            text: $viewModel.warmupProjectPathText
                        )
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        HStack {
                            Button("Save Project Path") {
                                viewModel.saveWarmupProjectPath()
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button("Use .env/health") {
                                viewModel.clearWarmupProjectPath()
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.secondary)
                        }

                        LabeledContent("Source", value: viewModel.warmupProjectPathSourceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)

                    if let errorBanner = viewModel.errorBanner {
                        Text(errorBanner)
                            .font(.caption)
                            .foregroundStyle(.red)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 20) {
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
                        Spacer()
                        TextField(
                            "Default",
                            text: Binding(
                                get: { preference.warmupModel },
                                set: { onModelChange($0) }
                            )
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: 180)
                    }
                } else {
                    HStack {
                        Text("Model")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Picker("", selection: modelSelection) {
                            Text("Default").tag("")
                            ForEach(menuOptions, id: \.self) { model in
                                Text(modelRowTitle(for: model))
                                    .tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical, 6)
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
