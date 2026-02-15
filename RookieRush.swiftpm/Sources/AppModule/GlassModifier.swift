import SwiftUI

// MARK: - Glass Effect Modifier (iOS 26+)

/// Conditionally applies the Liquid Glass effect on iOS 26+.
/// On earlier versions, this is a no-op, preserving the existing background styling.
///
/// Usage:
///   .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 16)))
///   .modifier(GlassModifier(shape: Capsule(), tint: .orange))
struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply Liquid Glass with a rounded rectangle shape (iOS 26+, no-op on earlier).
    func glassBackground(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
        self.modifier(GlassModifier(
            shape: RoundedRectangle(cornerRadius: cornerRadius),
            tint: tint
        ))
    }

    /// Apply Liquid Glass with a capsule shape (iOS 26+, no-op on earlier).
    func glassCapsule(tint: Color? = nil) -> some View {
        self.modifier(GlassModifier(
            shape: Capsule(),
            tint: tint
        ))
    }
}
