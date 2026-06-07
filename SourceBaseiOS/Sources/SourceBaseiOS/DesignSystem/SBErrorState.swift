import SwiftUI

/// Context variants for error states
public enum SBErrorContext {
    case generic
    case drive
    case baseForce
    case generation
    case network

    var tint: Color {
        switch self {
        case .generic, .drive, .network: return SBColors.red
        case .baseForce: return SBColors.red
        case .generation: return SBColors.orange
        }
    }

    var recoveryHint: String? {
        switch self {
        case .drive: return "Bağlantını kontrol edip tekrar dene."
        case .baseForce: return "Kaynak durumunu kontrol edebilirsin."
        case .generation: return "Farklı bir kaynak veya mod deneyebilirsin."
        case .network: return "İnternet bağlantını kontrol et."
        case .generic: return nil
        }
    }
}

public struct SBErrorState: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let onAction: (() -> Void)?
    let secondaryLabel: String?
    let onSecondaryAction: (() -> Void)?
    let context: SBErrorContext

    public init(
        icon: String = "exclamationmark.triangle",
        title: String = "Bir sorun oluştu",
        message: String,
        actionLabel: String? = "Tekrar dene",
        onAction: (() -> Void)? = nil,
        secondaryLabel: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        context: SBErrorContext = .generic
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.secondaryLabel = secondaryLabel
        self.onSecondaryAction = onSecondaryAction
        self.context = context
    }

    public var body: some View {
        VStack(spacing: SBSpacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(context.tint.opacity(0.10))
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .sbScaledFont(size: 32, weight: .medium)
                    .foregroundStyle(context.tint)
            }

            VStack(spacing: SBSpacing.sm) {
                Text(title)
                    .font(SBTypography.heading3)
                    .foregroundStyle(SBColors.navy)

                Text(message)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if let hint = context.recoveryHint {
                    Text(hint)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted.opacity(0.8))
                        .italic()
                        .padding(.top, 2)
                }
            }

            if let actionLabel, let onAction {
                HStack(spacing: SBSpacing.md) {
                    SBButton(
                        actionLabel,
                        icon: "arrow.clockwise",
                        variant: .primary,
                        size: .medium,
                        action: onAction
                    )

                    if let secondaryLabel, let onSecondaryAction {
                        SBButton(
                            secondaryLabel,
                            icon: "chevron.left",
                            variant: .secondary,
                            size: .medium,
                            action: onSecondaryAction
                        )
                    }
                }
            }
        }
        .padding(SBSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

public struct SBInlineError: View {
    let message: String
    let isWarning: Bool

    public init(message: String, isWarning: Bool = false) {
        self.message = message
        self.isWarning = isWarning
    }

    public var body: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .sbScaledFont(size: 18)
                .foregroundStyle(isWarning ? SBColors.warning : SBColors.red)

            Text(message)
                .font(SBTypography.bodySmall)
                .foregroundStyle(isWarning ? SBColors.warning : SBColors.red)
                .lineSpacing(2)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isWarning ? SBColors.warningBg : SBColors.redBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VStack(spacing: 32) {
        SBErrorState(
            title: "Bağlantı hatası",
            message: "Drive sunucusuna ulaşılamadı. İnternet bağlantını kontrol edebilirsin.",
            actionLabel: "Tekrar dene",
            onAction: {},
            context: .drive
        )

        Divider()

        SBInlineError(message: "E-posta veya şifre hatalı.")

        SBInlineError(message: "Dosya boyutu çok büyük.", isWarning: true)
    }
    .padding()
    .sbPageBackground()
}

// MARK: - Success State (Completion Surface)

/// Premium completion surface shown when generation is queued or result is ready.
public struct SBSuccessState: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let onAction: (() -> Void)?
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var pulseGlow = false

    public init(
        icon: String = "checkmark.seal.fill",
        title: String = "Hazır",
        message: String,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil,
        tint: Color = SBColors.green
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: SBSpacing.xl) {
            ZStack {
                // Calm glow ring
                Circle()
                    .fill(tint.opacity(pulseGlow && !reduceMotion ? 0.12 : 0.06))
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulseGlow && !reduceMotion ? 1.08 : 1)
                    .animation(.easeInOut(duration: 1.4).repeatCount(2, autoreverses: true), value: pulseGlow)

                RoundedRectangle(cornerRadius: 22)
                    .fill(tint.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .sbScaledFont(size: 32, weight: .semibold)
                    .foregroundStyle(tint)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
            }

            VStack(spacing: SBSpacing.sm) {
                Text(title)
                    .font(SBTypography.heading3)
                    .foregroundStyle(SBColors.navy)

                Text(message)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            if let actionLabel, let onAction {
                SBButton(
                    actionLabel,
                    icon: "arrow.right",
                    variant: .primary,
                    size: .medium,
                    action: onAction
                )
                .opacity(appeared ? 1 : 0)
            }
        }
        .padding(SBSpacing.xxl)
        .frame(maxWidth: .infinity)
        .onAppear {
            if !reduceMotion {
                withAnimation(SBMotion.softSpring.delay(0.1)) { appeared = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pulseGlow = true
                }
            } else {
                appeared = true
            }
        }
    }
}
