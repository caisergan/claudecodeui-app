import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    submit()
                }

            Button(action: submit) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .fontWeight(.bold)
                    }
                }
                .frame(width: 36, height: 36)
                .background(canSend ? .indigo : .secondary.opacity(0.4), in: Circle())
                .foregroundStyle(.white)
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        !text.isBlank && !isLoading
    }

    private func submit() {
        guard canSend else { return }
        onSend()
    }
}
