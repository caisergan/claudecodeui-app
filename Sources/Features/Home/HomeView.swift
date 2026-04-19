import SwiftUI

// MARK: - Usage Row

struct UsageRow: View {
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

struct WarmupRow: View {
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

// MARK: - HomeView

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            List {
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

                // MARK: - Conversations
                Section("Conversations") {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if viewModel.conversations.isEmpty {
                        ContentUnavailableView(
                            "No Conversations",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Start a new conversation to get started.")
                        )
                    } else {
                        ForEach(viewModel.conversations) { conversation in
                            ConversationRowView(conversation: conversation)
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.createConversation()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .task {
            viewModel.loadProviderSettings()
            await viewModel.loadConversations()
            await viewModel.refreshUsage()
        }
        .onDisappear {
            viewModel.cancelAllResetTimers()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

#Preview {
    HomeView()
}