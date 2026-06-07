import SwiftUI

/// Context variants provide branded, context-specific empty states
/// while sharing the same structural DNA.
public enum SBEmptyStateContext {
    case generic
    case drive
    case baseForce
    case generationWaiting
    case sourceMissing
    case completedSuccess

    var tint: Color {
        switch self {
        case .generic: return SBColors.blue
        case .drive: return SBColors.blue
        case .baseForce: return SBColors.cyan
        case .generationWaiting: return SBColors.purple
        case .sourceMissing: return SBColors.warning
        case .completedSuccess: return SBColors.green
        }
    }

    var motivationLine: String? {
        switch self {
        case .drive: return "Her yüklenen kaynak seni bir adım öne taşır."
        case .baseForce: return "Doğru kaynak, doğru çıktıya giden ilk adım."
        case .generationWaiting: return "Biraz sabır, kaliteli sonuç geliyor."
        case .completedSuccess: return "Harika iş. Şimdi çalışmaya geçebilirsin."
        case .sourceMissing: return "Uygun bir kaynak seçince devam edebilirsin."
        case .generic: return nil
        }
    }
}

public struct SBEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let badges: [String]
    let actionLabel: String?
    let onAction: (() -> Void)?
    let secondaryLabel: String?
    let onSecondaryAction: (() -> Void)?
    let context: SBEmptyStateContext

    public init(
        icon: String = "folder",
        title: String,
        message: String,
        badges: [String] = [],
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil,
        secondaryLabel: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        context: SBEmptyStateContext = .generic
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.badges = badges
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.secondaryLabel = secondaryLabel
        self.onSecondaryAction = onSecondaryAction
        self.context = context
    }

    public var body: some View {
        SBCard(radius: 20) {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(context.tint.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .sbScaledFont(size: 26, weight: .medium)
                        .foregroundStyle(context.tint)
                }

                // Title
                Text(title)
                    .font(SBTypography.heading2)
                    .foregroundStyle(SBColors.navy)

                // Message
                Text(message)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Motivation line
                if let motivation = context.motivationLine {
                    Text(motivation)
                        .font(SBTypography.caption)
                        .foregroundStyle(context.tint.opacity(0.82))
                        .italic()
                }

                // Badges
                if !badges.isEmpty {
                    FlowLayout(spacing: SBSpacing.sm) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
                                .font(SBTypography.labelSmall)
                                .foregroundStyle(context.tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(context.tint.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Actions
                if let actionLabel, let onAction {
                    HStack(spacing: SBSpacing.md) {
                        SBButton(
                            actionLabel,
                            icon: "arrow.right",
                            variant: .primary,
                            size: .small,
                            action: onAction
                        )

                        if let secondaryLabel, let onSecondaryAction {
                            SBButton(
                                secondaryLabel,
                                icon: "arrow.up.right",
                                variant: .secondary,
                                size: .small,
                                action: onSecondaryAction
                            )
                        }
                    }
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    SBEmptyState(
        icon: "folder.badge.plus",
        title: "Henüz kaynak yok",
        message: "PDF, PPTX, DOCX, PPT veya DOC yükleyerek çalışma materyali üretmeye başlayabilirsin.",
        badges: ["PDF", "PPTX", "DOCX"],
        actionLabel: "Kaynak yükle",
        onAction: {},
        secondaryLabel: "Ders oluştur",
        onSecondaryAction: {}
    )
    .padding()
    .sbPageBackground()
}
