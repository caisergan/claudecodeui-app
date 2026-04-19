import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // MARK: - Logo
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 56, weight: .semibold))
                                .foregroundStyle(.indigo.gradient)

                            Text("ClaudeCodeUI")
                                .font(.largeTitle.bold())

                            Text("Sign in to continue")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)

                        // MARK: - Form
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Username")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("your-username", text: $viewModel.username)
                                    .textContentType(.username)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                SecureField("••••••••", text: $viewModel.password)
                                    .textContentType(.password)
                                    .padding(14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // MARK: - Action
                        VStack(spacing: 12) {
                            LoadingButton(
                                title: "Sign In",
                                isLoading: viewModel.isLoading
                            ) {
                                Task { await viewModel.login(appState: appState) }
                            }
                            .disabled(!viewModel.isFormValid)

                            Button("Forgot password?") {
                                viewModel.showForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Sign In Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
        .sheet(isPresented: $viewModel.showForgotPassword) {
            ForgotPasswordView()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
