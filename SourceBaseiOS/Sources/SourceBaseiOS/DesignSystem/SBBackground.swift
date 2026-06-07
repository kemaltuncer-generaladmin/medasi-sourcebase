import SwiftUI

/// Tab-level tonal bias for subtle subconscious differentiation.
public enum SBPageTone {
    case neutral
    case warm      // Drive — slightly warmer
    case cool      // BaseForce — slightly cooler
    case study     // Study — balanced neutral with minimal warmth

    var biasGradient: LinearGradient {
        switch self {
        case .neutral:
            return LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        case .warm:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.92).opacity(0.035),
                    .clear,
                    Color(red: 0.98, green: 0.94, blue: 0.90).opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cool:
            return LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.04),
                    .clear,
                    Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .study:
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.94, blue: 1.0).opacity(0.03),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Calm page background for dense study workflows.
public struct SBAmbientBackground: View {
    let tone: SBPageTone

    public init(tone: SBPageTone = .neutral) {
        self.tone = tone
    }

    public var body: some View {
        ZStack {
            SBColors.pageGradient

            LinearGradient(
                colors: [
                    SBColors.blue.opacity(0.08),
                    .clear,
                    SBColors.orange.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    SBColors.white.opacity(0.55),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            // Tonal bias layer
            tone.biasGradient
        }
        .ignoresSafeArea()
    }
}

public extension View {
    /// Applies the ambient SourceBase page background.
    func sbPageBackground(tone: SBPageTone = .neutral) -> some View {
        background(SBAmbientBackground(tone: tone))
    }
}
