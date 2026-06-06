import SwiftUI

/// Calm page background for dense study workflows.
public struct SBAmbientBackground: View {
    public init() {}

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
        }
        .ignoresSafeArea()
    }
}

public extension View {
    /// Applies the ambient SourceBase page background.
    func sbPageBackground() -> some View {
        background(SBAmbientBackground())
    }
}
