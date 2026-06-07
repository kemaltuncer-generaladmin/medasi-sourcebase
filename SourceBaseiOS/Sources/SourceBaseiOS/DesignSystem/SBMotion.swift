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
    /// Calm completion pulse.
    public static let completionPulse = Animation.easeInOut(duration: 0.6)
    /// Breathing loop for subtle emphasis.
    public static let breathe = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

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

// MARK: - Selection delight

private struct SBSelectionDelightModifier: ViewModifier {
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(!reduceMotion && isSelected ? 1.02 : 1)
            .animation(reduceMotion ? nil : SBMotion.spring, value: isSelected)
    }
}

public extension View {
    /// Brief scale delight when a source is selected.
    func sbSelectionDelight(_ isSelected: Bool) -> some View {
        modifier(SBSelectionDelightModifier(isSelected: isSelected))
    }
}

// MARK: - Completion glow

private struct SBCompletionGlowModifier: ViewModifier {
    let isComplete: Bool
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tint.opacity(isComplete && !reduceMotion && glowing ? 0.28 : 0), lineWidth: 2)
                    .animation(SBMotion.completionPulse, value: glowing)
            )
            .onChange(of: isComplete) { _, newValue in
                if newValue && !reduceMotion {
                    glowing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(SBMotion.ease) { glowing = false }
                    }
                }
            }
    }
}

public extension View {
    /// Calm glow pulse on completion — not confetti, just a dignified acknowledgement.
    func sbCompletionGlow(_ isComplete: Bool, tint: Color = SBColors.green) -> some View {
        modifier(SBCompletionGlowModifier(isComplete: isComplete, tint: tint))
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

// MARK: - Breathing emphasis for quick continue

private struct SBBreathingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(breathing && !reduceMotion ? 1.008 : 1)
            .shadow(
                color: SBColors.blue.opacity(breathing && !reduceMotion ? 0.08 : 0.03),
                radius: breathing ? 12 : 8,
                x: 0,
                y: breathing ? 6 : 4
            )
            .onAppear {
                if !reduceMotion {
                    withAnimation(SBMotion.breathe) { breathing = true }
                }
            }
    }
}

public extension View {
    /// Subtle breathing emphasis for quick-continue surfaces.
    func sbBreathing() -> some View {
        modifier(SBBreathingModifier())
    }
}
