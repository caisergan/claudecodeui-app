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

                // MARK: - Usage
                if !viewModel.enabledProviders.isEmpty {
                    Section {
                        if viewModel.isLoadingUsage {
                            HStack {
                                ProgressView()
                                Text("Loading usage...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if viewModel.usageSummaries.isEmpty {
                            Text("No usage data")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.usageSummaries) { usage in
                                UsageRow(usage: usage)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Usage")
                            Spacer()
                            Button {
                                Task { await viewModel.refreshUsage() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                        }
                    }
                }

                // MARK: - Warmup
                if !viewModel.enabledProviders.isEmpty {
                    Section("Warmup") {
                        ForEach(viewModel.enabledProviders) { provider in
                            WarmupRow(
                                provider: provider,
                                state: viewModel.warmupStates[provider] ?? .idle,
                                onWarmup: {
                                    Task { await viewModel.warmupProvider(provider) }
                                }
                            )
                        }
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
                await viewModel.refreshUsage()
            }
            .onDisappear {
                viewModel.cancelAllResetTimers()
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

    @State private var modelText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(provider.displayName, isOn: Binding(
                get: { preference.isEnabled },
                set: { onToggle($0) }
            ))

            if preference.isEnabled {
                HStack {
                    Text("Model")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Default", text: $modelText)
                        .font(.subheadline)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { onModelChange(modelText) }
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear { modelText = preference.warmupModel }
        .onChange(of: preference.warmupModel) { _, newValue in
            modelText = newValue
        }
    }
}

// MARK: - Usage Row

private struct UsageRow: View {
    let usage: ProviderUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(usage.provider.displayName)
                .font(.subheadline.bold())
            Text(usage.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let resetTime = usage.resetTime {
                Text("Resets: \(resetTime)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Warmup Row

private struct WarmupRow: View {
    let provider: AIProvider
    let state: WarmupState
    let onWarmup: () -> Void

    var body: some View {
        HStack {
            Text(provider.displayName)
                .font(.subheadline)

            Spacer()

            switch state {
            case .idle:
                Button(action: onWarmup) {
                    Image(systemName: "flame")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .help(message)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
