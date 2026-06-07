import SwiftUI

public struct SBCard<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let showShadow: Bool
    let content: () -> Content

    public init(
        padding: CGFloat = SBSpacing.cardPadding,
        radius: CGFloat = 12,
        backgroundColor: Color = SBColors.white,
        borderColor: Color = SBColors.softLine,
        showShadow: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.showShadow = showShadow
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                // Raised edge: lighter at the top, settling into the border colour.
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        LinearGradient(
                            colors: [SBColors.white.opacity(0.82), borderColor],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // Layered shadow: a soft ambient drop plus a tight contact shadow so
            // cards read as floating above the surface, not painted onto it.
            .shadow(
                color: showShadow ? SBColors.navy.opacity(0.065) : .clear,
                radius: showShadow ? 14 : 0,
                x: 0,
                y: showShadow ? 8 : 0
            )
            .shadow(
                color: showShadow ? SBColors.navy.opacity(0.035) : .clear,
                radius: showShadow ? 3 : 0,
                x: 0,
                y: showShadow ? 1 : 0
            )
    }
}

public struct SBTappableCard<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let action: () -> Void
    let content: () -> Content

    public init(
        padding: CGFloat = SBSpacing.cardPadding,
        radius: CGFloat = 12,
        backgroundColor: Color = SBColors.white,
        borderColor: Color = SBColors.softLine,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            SBCard(
                padding: padding,
                radius: radius,
                backgroundColor: backgroundColor,
                borderColor: borderColor,
                content: content
            )
        }
        .buttonStyle(PressableCardStyle())
    }
}

struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.975 : 1)
            .shadow(
                color: SBColors.navy.opacity(configuration.isPressed ? 0.03 : 0),
                radius: configuration.isPressed ? 2 : 0,
                x: 0,
                y: configuration.isPressed ? 1 : 0
            )
            .animation(reduceMotion ? nil : SBMotion.pressSpring, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        SBCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Başlık")
                    .font(SBTypography.heading3)
                    .foregroundStyle(SBColors.navy)
                Text("Açıklama metni burada yer alır.")
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
            }
        }

        SBTappableCard(action: {}) {
            HStack {
                Text("Tıklanabilir Kart")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)
                Spacer()
                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(SBColors.softText)
            }
        }
    }
    .padding()
    .sbPageBackground()
}
