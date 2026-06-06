import SwiftUI

/// Centralised motion language for SourceBase. Keeps animations consistent,
/// calm and premium across every screen.
public enum SBMotion {
    /// Standard spring for taps, toggles and small state changes.
    public static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// Softer spring for larger transitions (sheets, hero reveals).
    public static let softSpring = Animation.spring(response: 0.55, dampingFraction: 0.86)
    /// Snappy spring for press feedback.
    public static let pressSpring = Animation.spring(response: 0.28, dampingFraction: 0.7)
    /// Gentle ease for fades.
    public static let ease = Animation.easeInOut(duration: 0.25)

    /// Per-item delay used by staggered entrance animations.
    public static func stagger(_ index: Int, step: Double = 0.06, cap: Int = 8) -> Double {
        Double(min(index, cap)) * step
    }
}

// MARK: - Staggered entrance

private struct SBEntranceModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (reduceMotion ? 0 : 14))
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.985), anchor: .top)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(SBMotion.softSpring.delay(SBMotion.stagger(index))) {
                        appeared = true
                    }
                }
            }
    }
}

public extension View {
    /// Fades and lifts a view in on appear, staggered by `index` so a column of
    /// cards cascades into place.
    func sbEntrance(_ index: Int = 0) -> some View {
        modifier(SBEntranceModifier(index: index))
    }
}

// MARK: - Press feedback

/// A button style that adds a calm spring press-scale. Use for tappable cards
/// and tiles that are not already wrapped in `SBTappableCard`.
public struct SBPressStyle: ButtonStyle {
    public init() {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : SBMotion.pressSpring, value: configuration.isPressed)
    }
}
