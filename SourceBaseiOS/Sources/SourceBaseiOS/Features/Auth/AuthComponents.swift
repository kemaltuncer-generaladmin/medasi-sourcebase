import SwiftUI

// Shared, calm-clinical building blocks for the login + setup flow. No neon,
// no "magic" AI gradients — a soft branded mark, clean cards, and tactile
// selectable controls that match the SourceBase design system.

/// Branded header: a soft accent halo behind the SourceBase mark, with title
/// and subtitle. Used at the top of the auth + profile-setup screens.
struct AuthBrandHeader: View {
    var title: String = "SourceBase"
    var subtitle: String
    var compact: Bool = false

    private var markSize: CGFloat { compact ? 60 : 76 }

    var body: some View {
        VStack(spacing: SBSpacing.lg) {
            ZStack {
                Circle()
                    .fill(SBColors.blue.opacity(0.12))
                    .frame(width: markSize * 1.9, height: markSize * 1.9)
                    .blur(radius: 26)

                RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                    .fill(SBColors.brandGradient)
                    .frame(width: markSize, height: markSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: SBColors.blue.opacity(0.30), radius: 22, x: 0, y: 14)

                Image(systemName: "books.vertical.fill")
                    .sbScaledFont(size: compact ? 26 : 32, weight: .semibold)
                    .foregroundStyle(.white)
            }

            VStack(spacing: SBSpacing.xs) {
                Text(title)
                    .font(compact ? SBTypography.heading2 : SBTypography.display2)
                    .foregroundStyle(SBColors.navy)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Slim discipline chips that communicate SourceBase's multi-discipline value.
struct AuthDisciplineChips: View {
    private let items = ["Veterinerlik", "Tıp", "Diş", "Hemşirelik", "Ebelik"]

    var body: some View {
        FlowLayout(spacing: SBSpacing.sm) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.blue)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(SBColors.softBlue, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Tactile pill for single-select options (class year, goal).
struct SBSelectPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SBTypography.labelMedium)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
                .padding(.horizontal, SBSpacing.lg)
                .padding(.vertical, 10)
                .background(
                    isSelected ? AnyShapeStyle(SBColors.primaryGradient) : AnyShapeStyle(SBColors.white),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : SBColors.line, lineWidth: 1)
                )
                .shadow(color: isSelected ? SBColors.blue.opacity(0.22) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Selectable discipline card (icon + label) for the profile-setup grid.
struct SBDisciplineCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SBSpacing.sm) {
                Image(systemName: icon)
                    .sbScaledFont(size: 22, weight: .semibold)
                    .foregroundStyle(isSelected ? .white : SBColors.blue)
                    .frame(width: 46, height: 46)
                    .background(
                        isSelected ? AnyShapeStyle(SBColors.primaryGradient) : AnyShapeStyle(SBColors.softBlue),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                Text(title)
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SBSpacing.lg)
            .background(SBColors.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? SBColors.blue : SBColors.softLine, lineWidth: isSelected ? 1.6 : 1)
            )
            .shadow(color: SBColors.navy.opacity(isSelected ? 0.10 : 0.04), radius: isSelected ? 12 : 6, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Labeled section wrapper used in the profile-setup form.
struct SBFieldSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(SBColors.blue)
                Text(title)
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
