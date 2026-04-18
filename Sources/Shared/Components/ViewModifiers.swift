import SwiftUI

// MARK: - Card Style

struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.md
    var cornerRadius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Theme.Shadow.soft.color,
                radius: Theme.Shadow.soft.radius,
                x: Theme.Shadow.soft.x,
                y: Theme.Shadow.soft.y
            )
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonModifier: ViewModifier {
    var isDisabled: Bool = false

    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isDisabled
                    ? AnyShapeStyle(Color.secondary.opacity(0.3))
                    : AnyShapeStyle(Theme.Colors.accentGradient),
                in: RoundedRectangle(cornerRadius: Theme.Radius.md)
            )
            .animation(.easeInOut(duration: 0.15), value: isDisabled)
    }
}

// MARK: - Shake (for validation errors)

struct ShakeModifier: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Loading Overlay

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.4)
                            .padding(Theme.Spacing.xl)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(padding: CGFloat = Theme.Spacing.md, cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    func primaryButton(isDisabled: Bool = false) -> some View {
        modifier(PrimaryButtonModifier(isDisabled: isDisabled))
    }

    func shake(trigger: CGFloat) -> some View {
        modifier(ShakeModifier(animatableData: trigger))
    }

    func loadingOverlay(isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}
