import SwiftUI

/// Constrains content to a readable column on iPad (≤720pt wide, centred).
/// On iPhone the constraint has no effect.
struct SBReadableContainer: ViewModifier {
    var maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Wrap content in a max-width readable column; centres on wide screens.
    func sbReadableWidth(_ maxWidth: CGFloat = 720) -> some View {
        modifier(SBReadableContainer(maxWidth: maxWidth))
    }
}
