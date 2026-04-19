import SwiftUI

// MARK: - Usage Row

struct UsageRow: View {
    let usage: ProviderUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.provider.displayName)
                    .font(.subheadline.bold())

                Spacer(minLength: 12)

                UsageStatusBadge(status: usage.status)
            }

            if !usage.quotaWindows.isEmpty {
                ForEach(usage.quotaWindows) { window in
                    QuotaBar(window: window)
                }
            } else if let message = usage.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let footer = footerText {
                Text(footer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var footerText: String? {
        var parts: [String] = []
        if let metadata = usage.metadata, !metadata.isEmpty {
            parts.append(metadata)
        }
        if let resetTime = usage.resetTime, resetTime > .now {
            parts.append("Resets at \(resetTime.absoluteTimeDescription)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct QuotaBar: View {
    let window: QuotaWindowDisplay

    var body: some View {
        HStack(spacing: 8) {
            Text(window.label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    Capsule()
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * window.remaining / 100))
                }
            }
            .frame(height: 6)

            Text("\(Int(window.remaining.rounded()))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var barColor: Color {
        if window.remaining > 50 { return .green }
        if window.remaining > 20 { return .orange }
        return .red
    }
}

private struct UsageStatusBadge: View {
    let status: ProviderUsageStatus

    var body: some View {
        Text(status.badgeTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .ready:
            return .green
        case .limited:
            return .orange
        case .actionRequired:
            return .red
        case .unsupported:
            return .secondary
        case .preview:
            return .blue
        case .unknown:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .ready:
            return .green.opacity(0.12)
        case .limited:
            return .orange.opacity(0.14)
        case .actionRequired:
            return .red.opacity(0.12)
        case .unsupported, .unknown:
            return .secondary.opacity(0.12)
        case .preview:
            return .blue.opacity(0.12)
        }
    }
}

// MARK: - Warmup Row

struct WarmupRow: View {
    let provider: AIProvider
    let state: WarmupState
    let lastSuccessfulWarmupDate: Date?
    let onWarmup: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.subheadline)

                if let lastSuccessfulWarmupDate {
                    Text("Last success \(lastSuccessfulWarmupDate.absoluteTimeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

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
                if !viewModel.usageProviders.isEmpty {
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
                                Task { await viewModel.refreshUsage(forceRefresh: true) }
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
                                lastSuccessfulWarmupDate: viewModel.lastSuccessfulWarmupDates[provider],
                                onWarmup: {
                                    Task { await viewModel.warmupProvider(provider) }
                                }
                            )
                        }
                    }
                }

            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            viewModel.loadProviderSettings()
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
