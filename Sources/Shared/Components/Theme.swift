import SwiftUI

// MARK: - Theme
//
// Single source of truth for colors, typography, spacing and radius.
// Use these instead of hard-coded values anywhere in the codebase.
//
// Usage:
//   Text("Hello").font(Theme.Typography.headline)
//   view.padding(Theme.Spacing.md)
//   Color(Theme.Colors.accent)

enum Theme {

    // MARK: Colors
    enum Colors {
        /// Primary brand / CTA color
        static let accent        = Color.indigo
        /// Accent gradient (top-left → bottom-right)
        static let accentGradient = LinearGradient(
            colors: [.indigo, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// Success states
        static let success       = Color.green
        /// Error / destructive
        static let danger        = Color.red
        /// Warning
        static let warning       = Color.orange
        /// Subtle backgrounds
        static let surface       = Color(.systemBackground)
        static let surfaceSecondary = Color(.secondarySystemBackground)
        static let surfaceTertiary  = Color(.tertiarySystemBackground)
    }

    // MARK: Typography
    enum Typography {
        static let largeTitle  = Font.largeTitle.bold()
        static let title       = Font.title2.bold()
        static let headline    = Font.headline
        static let body        = Font.body
        static let subheadline = Font.subheadline
        static let caption     = Font.caption
        static let caption2    = Font.caption2
        static let monospaced  = Font.system(.body, design: .monospaced)
    }

    // MARK: Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner Radius
    enum Radius {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: Shadows
    enum Shadow {
        static let soft  = (color: Color.black.opacity(0.06), radius: CGFloat(8),  x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.10), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
    }
}
