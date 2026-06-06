import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Haptics

/// Lightweight haptic feedback helper. No-op on non-iOS platforms.
public enum SBHaptics {
    public enum Impact { case light, medium, soft, rigid }

    public static func tap(_ impact: Impact = .light) {
        #if os(iOS)
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch impact {
        case .light: style = .light
        case .medium: style = .medium
        case .soft: style = .soft
        case .rigid: style = .rigid
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    public static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    public static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

// MARK: - Gradient helpers

public extension SBColors {
    /// Soft diagonal gradient for icon tiles, giving them dimension instead of a flat tint.
    static func tileGradient(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.22), tint.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Rich diagonal gradient from a base tint to a slightly deeper shade.
    static func deepGradient(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint, tint.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Gradient icon tile

/// A dimensional icon container: gradient fill, hairline highlight and a soft
/// tinted glow. Drop-in replacement for flat `tint.opacity(0.12)` squares.
public struct SBIconTile: View {
    let icon: String
    let tint: Color
    let size: CGFloat
    let radius: CGFloat

    public init(icon: String, tint: Color, size: CGFloat = 48, radius: CGFloat = 14) {
        self.icon = icon
        self.tint = tint
        self.size = size
        self.radius = radius
    }

    public var body: some View {
        Image(systemName: icon)
            .sbScaledFont(size: size * 0.42, weight: .semibold)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(SBColors.tileGradient(tint))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Animated circular progress ring

/// A premium circular progress indicator with a gradient stroke, a soft
/// rotating glow and the percentage in the centre. Used as the focal point of
/// the generation screen.
public struct SBProgressRing: View {
    let progress: Double
    let tint: Color
    let lineWidth: CGFloat
    let diameter: CGFloat

    public init(progress: Double, tint: Color, lineWidth: CGFloat = 12, diameter: CGFloat = 132) {
        self.progress = progress
        self.tint = tint
        self.lineWidth = lineWidth
        self.diameter = diameter
    }

    @State private var spin = false

    public var body: some View {
        ZStack {
            // track
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: lineWidth)

            // rotating ambient glow behind the ring
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: diameter * 0.7, height: diameter * 0.7)
                .blur(radius: 24)
                .scaleEffect(spin ? 1.05 : 0.92)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: spin)

            // progress arc
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(0.5), tint, SBColors.cyan, tint]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(SBMotion.softSpring, value: progress)

            // centre label
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .sbScaledFont(size: diameter * 0.26, weight: .bold, design: .rounded)
                    .foregroundStyle(SBColors.navy)
                    .contentTransition(.numericText())
                    .animation(SBMotion.spring, value: progress)
                Text("%")
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.muted)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { spin = true }
    }
}
