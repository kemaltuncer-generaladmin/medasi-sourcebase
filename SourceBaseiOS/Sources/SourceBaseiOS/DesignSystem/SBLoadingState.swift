import SwiftUI
import Shimmer

/// Context variants for loading states
public enum SBLoadingContext {
    case generic
    case drive
    case baseForce
    case generation

    var tint: Color {
        switch self {
        case .generic, .drive: return SBColors.blue
        case .baseForce: return SBColors.cyan
        case .generation: return SBColors.purple
        }
    }

    var calmLine: String? {
        switch self {
        case .drive: return "Kaynakların düzenleniyor..."
        case .baseForce: return "Üretim araçları hazırlanıyor..."
        case .generation: return "Kaliteli sonuç biraz zaman alır."
        case .generic: return nil
        }
    }
}

public struct SBLoadingState: View {
    let icon: String
    let title: String
    let message: String
    let context: SBLoadingContext

    public init(
        icon: String = "hourglass",
        title: String = "Yükleniyor",
        message: String = "Lütfen bekleyin...",
        context: SBLoadingContext = .generic
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            // Header chip
            HStack(spacing: SBSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(context.tint.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .sbScaledFont(size: 20, weight: .medium)
                        .foregroundStyle(context.tint)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(SBTypography.titleMedium)
                        .foregroundStyle(SBColors.navy)
                    Text(message)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                    if let calmLine = context.calmLine {
                        Text(calmLine)
                            .font(SBTypography.caption)
                            .foregroundStyle(context.tint.opacity(0.72))
                            .italic()
                    }
                }
                Spacer()
            }

            // Skeleton cards
            ForEach(0..<3, id: \.self) { _ in
                SBSkeletonCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmering()
    }
}

/// A single loading card used inside skeleton states.
public struct SBSkeletonCard: View {
    public init() {}
    public var body: some View {
        HStack(spacing: SBSpacing.md) {
            RoundedRectangle(cornerRadius: 12)
                .fill(SBColors.field)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(SBColors.field)
                    .frame(height: 13)
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 6)
                    .fill(SBColors.field)
                    .frame(width: 160, height: 11)
                RoundedRectangle(cornerRadius: 6)
                    .fill(SBColors.field)
                    .frame(width: 90, height: 11)
            }
            Spacer(minLength: 0)
        }
        .padding(SBSpacing.lg)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SBColors.softLine, lineWidth: 1))
    }
}

public struct SBInlineLoading: View {
    let message: String

    public init(message: String = "Yükleniyor...") {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: SBSpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: SBColors.blue))

            Text(message)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
        .padding(SBSpacing.lg)
        .shimmering()
    }
}

#Preview {
    VStack(spacing: 32) {
        SBLoadingState(
            icon: "checkmark.shield",
            title: "Oturum hazırlanıyor",
            message: "Oturum doğrulanıyor."
        )

        Divider()

        SBInlineLoading(message: "Dosyalar yükleniyor...")
    }
    .padding()
    .sbPageBackground()
}
