import SwiftUI

public struct SBErrorState: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let onAction: (() -> Void)?
    let secondaryLabel: String?
    let onSecondaryAction: (() -> Void)?

    public init(
        icon: String = "exclamationmark.triangle",
        title: String = "Bir sorun oluştu",
        message: String,
        actionLabel: String? = "Tekrar Dene",
        onAction: (() -> Void)? = nil,
        secondaryLabel: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.secondaryLabel = secondaryLabel
        self.onSecondaryAction = onSecondaryAction
    }

    public var body: some View {
        VStack(spacing: SBSpacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(SBColors.redBg)
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .sbScaledFont(size: 32, weight: .medium)
                    .foregroundStyle(SBColors.red)
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
            actionLabel: "Tekrar Dene",
            onAction: {}
        )

        Divider()

        SBInlineError(message: "E-posta veya şifre hatalı.")

        SBInlineError(message: "Dosya boyutu çok büyük.", isWarning: true)
    }
    .padding()
    .sbPageBackground()
}
