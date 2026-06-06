import SwiftUI

struct WarmLaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var haloExpand = false
    @State private var appear = false

    var body: some View {
        ZStack {
            SBAmbientBackground()

            VStack(spacing: SBSpacing.xl) {
                Spacer()

                ZStack {
                    // Expanding glow halos behind the mark
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(SBColors.blue.opacity(0.18), lineWidth: 1.5)
                            .frame(width: 120 + CGFloat(ring) * 46, height: 120 + CGFloat(ring) * 46)
                            .scaleEffect(reduceMotion ? 1 : (haloExpand ? 1.12 : 0.9))
                            .opacity(reduceMotion ? 0.18 : (haloExpand ? 0 : 0.7))
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 2.2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(ring) * 0.5),
                                value: haloExpand
                            )
                    }

                    // Soft glow
                    Circle()
                        .fill(SBColors.blue.opacity(0.22))
                        .frame(width: 150, height: 150)
                        .blur(radius: 40)
                        .scaleEffect(reduceMotion ? 1 : (pulse ? 1.1 : 0.85))

                    // Logo mark
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(SBColors.brandGradient)
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(SBColors.white.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: SBColors.blue.opacity(0.4), radius: 28, x: 0, y: 18)

                        Image(systemName: "books.vertical.fill")
                            .sbScaledFont(size: 44, weight: .semibold)
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.03 : 0.97))
                    .animation(reduceMotion ? nil : .spring(response: 1.1, dampingFraction: 0.72).repeatForever(autoreverses: true), value: pulse)
                }
                .frame(height: 230)

                VStack(spacing: SBSpacing.sm) {
                    Text("SourceBase")
                        .sbScaledFont(size: 40, weight: .bold, design: .rounded)
                        .foregroundStyle(SBColors.navy)

                    Text("Kaynaklarını öğrenme sistemine dönüştür.")
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.muted)
                        .multilineTextAlignment(.center)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)

                loadingDots
                    .opacity(appear ? 1 : 0)

                Spacer()

                Text("Medasi ekosistemi · premium öğrenme deneyimi")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.softText)
                    .opacity(appear ? 1 : 0)
            }
            .padding(SBSpacing.xl)
        }
        .onAppear {
            if reduceMotion {
                appear = true
            } else {
                pulse = true
                haloExpand = true
                withAnimation(SBMotion.softSpring.delay(0.15)) { appear = true }
            }
        }
    }

    private var loadingDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(SBColors.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.0 : 0.5))
                    .opacity(reduceMotion ? 0.65 : (pulse ? 1 : 0.35))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                        value: pulse
                    )
            }
        }
    }
}

#Preview {
    WarmLaunchView()
}
