import SwiftUI

public enum SBButtonSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 48
        case .large: return 56
        }
    }

    var font: Font {
        switch self {
        case .small: return SBTypography.labelMedium
        case .medium: return SBTypography.labelLarge
        case .large: return SBTypography.titleMedium
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 20
        case .large: return 22
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        }
    }
}

public enum SBButtonVariant {
    case primary, secondary, text
}

public struct SBButton: View {
    let label: String
    let icon: String?
    let variant: SBButtonVariant
    let size: SBButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let fullWidth: Bool
    let action: () -> Void

    public init(
        _ label: String,
        icon: String? = nil,
        variant: SBButtonVariant = .primary,
        size: SBButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(
                            tint: variant == .primary ? .white : SBColors.blue
                        ))
                        .scaleEffect(0.8)
                } else if let icon {
                    Image(systemName: icon)
                        .sbScaledFont(size: size.iconSize, weight: .semibold)
                }
                Text(label)
                    .font(size.font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(height: size.height)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
        }
        .buttonStyle(SBButtonStyle(variant: variant, isLoading: isLoading))
        .disabled(isLoading || isDisabled)
        .accessibilityAddTraits(variant == .primary ? .isButton : [])
    }
}

struct SBButtonStyle: ButtonStyle {
    let variant: SBButtonVariant
    let isLoading: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: variant == .primary ? SBColors.blue.opacity(configuration.isPressed ? 0.08 : 0.22) : .clear,
                radius: configuration.isPressed ? 4 : 10,
                x: 0,
                y: configuration.isPressed ? 1 : 6
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .opacity(isLoading || !isEnabled ? 0.62 : 1)
            .animation(reduceMotion ? nil : SBMotion.pressSpring, value: configuration.isPressed)
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .primary, .secondary:
            return 12
        case .text:
            return 10
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return isEnabled ? .white : SBColors.muted
        case .secondary: return isEnabled ? SBColors.blue : SBColors.muted
        case .text: return isEnabled ? SBColors.blue : SBColors.muted
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            if isEnabled {
                SBColors.primaryGradient
            } else {
                SBColors.softLine
            }
        case .secondary:
            SBColors.blue.opacity(isEnabled ? 0.06 : 0.02)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? SBColors.blue : SBColors.softLine, lineWidth: 1.5)
                )
        case .text:
            Color.clear
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SBButton("Giriş yap", icon: "arrow.right", variant: .primary, size: .large, fullWidth: true) {}
        SBButton("Kayıt ol", variant: .secondary, size: .medium) {}
        SBButton("Şifremi Unuttum", variant: .text, size: .small) {}
        SBButton("Yükleniyor...", variant: .primary, isLoading: true) {}
    }
    .padding()
}
