import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 52))
                    .foregroundStyle(.indigo.gradient)
                    .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Reset Password")
                        .font(.title2.bold())
                    Text("We'll send a reset link to your email address.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if didSend {
                    Label("Check your inbox!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    LoadingButton(title: "Send Reset Link", isLoading: isLoading) {
                        sendReset()
                    }
                    .disabled(email.isBlank || !email.contains("@"))
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .animation(.spring(duration: 0.35), value: didSend)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func sendReset() {
        isLoading = true
        // Simulate network call — wire to API.forgotPassword when ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            withAnimation { didSend = true }
        }
    }
}

#Preview {
    ForgotPasswordView()
}
