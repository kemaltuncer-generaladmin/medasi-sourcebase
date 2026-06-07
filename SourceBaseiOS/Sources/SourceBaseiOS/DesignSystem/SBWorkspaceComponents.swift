import SwiftUI
import SourceBaseBackend

public struct SBWorkspaceShell<Content: View>: View {
    let spacing: CGFloat
    let showsBottomGuard: Bool
    let content: () -> Content

    public init(
        spacing: CGFloat = SBSpacing.lg,
        showsBottomGuard: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.showsBottomGuard = showsBottomGuard
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
                if showsBottomGuard {
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.horizontal, SBSpacing.lg)
            .padding(.top, SBSpacing.sm)
            .padding(.bottom, SBSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .sbPageBackground()
    }
}

public struct SBTopBar: View {
    let title: String
    let subtitle: String?
    let leadingIcon: String?
    let onSearch: (() -> Void)?
    let onNotifications: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        onSearch: (() -> Void)? = nil,
        onNotifications: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.onSearch = onSearch
        self.onNotifications = onNotifications
    }

    public var body: some View {
        HStack(alignment: .center, spacing: SBSpacing.md) {
            if let leadingIcon {
                RoundedRectangle(cornerRadius: 12)
                    .fill(SBColors.selectedBlue)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: leadingIcon)
                            .sbScaledFont(size: 19, weight: .semibold)
                            .foregroundStyle(SBColors.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SBTypography.heading1)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: SBSpacing.md)

            HStack(spacing: SBSpacing.xs) {
                if let onSearch {
                    topButton(icon: "magnifyingglass", label: "Ara", action: onSearch)
                }
                if let onNotifications {
                    topButton(icon: "bell", label: "Bildirimler", action: onNotifications)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func topButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .semibold)
                .foregroundStyle(SBColors.navy)
                .frame(width: 44, height: 44)
                .background(SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SBColors.softLine, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

public struct SBHeroPanel<Actions: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let actions: () -> Actions

    public init(
        eyebrow: String,
        title: String,
        message: String,
        icon: String,
        tint: Color = SBColors.blue,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.actions = actions
    }

    public var body: some View {
        SBCard(padding: SBSpacing.xl, radius: 18, backgroundColor: SBColors.white, borderColor: SBColors.line) {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(tint.opacity(0.10))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: icon)
                                .sbScaledFont(size: 24, weight: .semibold)
                                .foregroundStyle(tint)
                        )

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(eyebrow)
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(tint)
                            .textCase(.uppercase)

                        Text(title)
                            .font(SBTypography.heading2)
                            .foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(SBTypography.bodyMedium)
                            .foregroundStyle(SBColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                actions()
            }
        }
    }
}

public struct SBActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    public init(icon: String, title: String, subtitle: String, tint: Color = SBColors.blue, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.md) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.10))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .sbScaledFont(size: 20, weight: .semibold)
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                    Text(subtitle)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(SBColors.softText)
            }
        }
        .buttonStyle(PressableCardStyle())
    }
}

public struct SBNotice: View {
    let icon: String
    let message: String
    let tint: Color

    public init(icon: String = "info.circle", message: String, tint: Color = SBColors.blue) {
        self.icon = icon
        self.message = message
        self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .top, spacing: SBSpacing.md) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .semibold)
                .foregroundStyle(tint)

            Text(message)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

public struct SBSourceRow: View {
    let file: DriveFile
    let isSelected: Bool
    let action: () -> Void

    public init(file: DriveFile, isSelected: Bool = false, action: @escaping () -> Void) {
        self.file = file
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.md) {
                SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

                VStack(alignment: .leading, spacing: SBSpacing.xs) {
                    Text(file.title)
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(2)
                    Text("\(file.courseTitle) • \(file.updatedLabel)")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(1)
                }

                Spacer()

                SBStatusBadge(status: SBStatus.from(file.status), compact: true)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SBColors.blue)
                }
            }
            .padding(SBSpacing.md)
            .background(SBColors.white)
        }
        .buttonStyle(.plain)
    }
}

public struct SBGenerationCard: View {
    let output: GeneratedOutput
    let sourceTitle: String
    let action: () -> Void

    public init(output: GeneratedOutput, sourceTitle: String, action: @escaping () -> Void) {
        self.output = output
        self.sourceTitle = sourceTitle
        self.action = action
    }

    public var body: some View {
        SBTappableCard(radius: 16, action: action) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.10))
                        .frame(width: 42, height: 42)
                        .overlay(Image(systemName: icon).foregroundStyle(color))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(output.title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(1)
                        Text(sourceTitle)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    SBStatusBadge(status: .ready, compact: true)
                }

                Text(output.detail)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(3)
            }
        }
    }

    private var icon: String {
        switch output.kind {
        case .flashcard: return "rectangle.on.rectangle"
        case .question: return "questionmark.circle"
        case .summary: return "doc.text"
        case .examMorningSummary: return "alarm"
        case .algorithm: return "arrow.triangle.branch"
        case .comparison, .table: return "tablecells"
        case .clinicalScenario: return "cross.case"
        case .learningPlan: return "calendar.badge.clock"
        case .podcast: return "headphones"
        case .infographic: return "chart.bar"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        }
    }

    private var color: Color {
        switch output.kind {
        case .flashcard: return SBColors.blue
        case .question, .infographic: return SBColors.cyan
        case .summary, .examMorningSummary, .mindMap: return SBColors.purple
        case .algorithm, .podcast, .clinicalScenario: return SBColors.orange
        case .learningPlan: return SBColors.green
        case .comparison, .table: return SBColors.purple
        }
    }
}

public struct SBQuickContinueSurface: View {
    let eyebrow: String
    let title: String
    let message: String
    let metadata: String
    let actionLabel: String
    let icon: String
    let tint: Color
    let action: () -> Void

    public init(
        eyebrow: String,
        title: String,
        message: String,
        metadata: String,
        actionLabel: String,
        icon: String,
        tint: Color = SBColors.blue,
        action: @escaping () -> Void
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.metadata = metadata
        self.actionLabel = actionLabel
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        SBCommandCard(tint: tint, action: action) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    SBIconTile(icon: icon, tint: tint, size: 46, radius: 14)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(eyebrow)
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(tint)
                            .textCase(.uppercase)

                        Text(title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)

                        Text(message)
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: SBSpacing.sm)
                }

                HStack(spacing: SBSpacing.sm) {
                    Text(metadata)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(1)

                    Spacer(minLength: SBSpacing.sm)

                    HStack(spacing: 4) {
                        Text(actionLabel)
                            .font(SBTypography.labelSmall)
                        Image(systemName: "arrow.right")
                            .sbScaledFont(size: 12, weight: .semibold)
                    }
                    .foregroundStyle(tint)
                }
            }
        }
        .sbBreathing()
    }
}

public struct SBWorkspaceMomentumRibbon: View {
    let readyCount: Int
    let outputCount: Int
    let focusTitle: String

    public init(readyCount: Int, outputCount: Int, focusTitle: String) {
        self.readyCount = readyCount
        self.outputCount = outputCount
        self.focusTitle = focusTitle
    }

    public var body: some View {
        SBCard(padding: SBSpacing.md, radius: 18, backgroundColor: SBColors.white, borderColor: SBColors.softLine) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                Text("Bugünkü momentum")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)

                SBMetricRibbon(items: [
                    .init(icon: "checkmark.seal", value: "\(readyCount)", label: "hazır kaynak", tint: SBColors.green),
                    .init(icon: "sparkles.rectangle.stack", value: "\(outputCount)", label: "çalışma", tint: SBColors.purple),
                    .init(icon: "stethoscope", value: focusTitle, label: "odak konu", tint: SBColors.cyan)
                ])
            }
        }
    }
}

public struct SBBottomCTA<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(SBSpacing.md)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().fill(SBColors.softLine).frame(height: 1), alignment: .top)
    }
}
