import SwiftUI

public enum SBHeroMode {
    case action
    case progress
    case selection
}

/// Hero size controls padding and icon scale.
public enum SBHeroSize {
    case full      // Default — larger padding, bigger icon
    case compact   // Reduced vertical space, smaller icon — for secondary screens
}

public struct SBPageHeader: View {
    let title: String
    let subtitle: String
    let primaryIcon: String?
    let secondaryIcon: String?
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    public init(
        title: String,
        subtitle: String,
        primaryIcon: String? = nil,
        secondaryIcon: String? = nil,
        onPrimary: (() -> Void)? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryIcon = primaryIcon
        self.secondaryIcon = secondaryIcon
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    public var body: some View {
        HStack(alignment: .top, spacing: SBSpacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(SBTypography.heading1)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)

                Text(subtitle)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: SBSpacing.md)

            HStack(spacing: SBSpacing.xs) {
                if let primaryIcon, let onPrimary {
                    roundIconButton(icon: primaryIcon, action: onPrimary)
                }
                if let secondaryIcon, let onSecondary {
                    roundIconButton(icon: secondaryIcon, action: onSecondary)
                }
            }
        }
    }

    private func roundIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .semibold)
                .foregroundStyle(SBColors.navy)
                .frame(width: 44, height: 44)
                .background(SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(SBColors.softLine, lineWidth: 1)
                )
                .shadow(color: SBColors.navy.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: icon))
    }

    private func accessibilityLabel(for icon: String) -> String {
        switch icon {
        case "magnifyingglass": return "Ara"
        case "bell": return "Bildirimler"
        case "plus": return "Ekle"
        case "questionmark.circle": return "Yardım"
        case "xmark": return "Kapat"
        case "play.fill": return "Oynat"
        case "pause.fill": return "Duraklat"
        case "ellipsis": return "Diğer işlemler"
        default: return "Diğer işlem"
        }
    }
}

public struct SBGradientHero<Actions: View, Footer: View>: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color
    let size: SBHeroSize
    let actions: () -> Actions
    let footer: () -> Footer

    public init(
        icon: String,
        title: String,
        message: String,
        tint: Color = SBColors.blue,
        size: SBHeroSize = .full,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.tint = tint
        self.size = size
        self.actions = actions
        self.footer = footer
    }

    private var iconSize: CGFloat { size == .compact ? 42 : 54 }
    private var iconRadius: CGFloat { size == .compact ? 12 : 16 }
    private var iconFont: CGFloat { size == .compact ? 18 : 24 }
    private var padding: CGFloat { size == .compact ? SBSpacing.lg : SBSpacing.xl }

    public var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? SBSpacing.md : SBSpacing.lg) {
            HStack(alignment: .top, spacing: SBSpacing.md) {
                RoundedRectangle(cornerRadius: iconRadius)
                    .fill(tint.opacity(0.12))
                    .frame(width: iconSize, height: iconSize)
                    .overlay(
                        Image(systemName: icon)
                            .sbScaledFont(size: iconFont, weight: .semibold)
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: size == .compact ? 4 : 8) {
                    Text(title)
                        .font(size == .compact ? SBTypography.heading3 : SBTypography.heading2)
                        .foregroundStyle(SBColors.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(size == .compact ? SBTypography.bodySmall : SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            actions()
            footer()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColors.heroWash(tint))
        .clipShape(RoundedRectangle(cornerRadius: size == .compact ? 20 : 26))
        .overlay(
            RoundedRectangle(cornerRadius: size == .compact ? 20 : 26)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.10), radius: size == .compact ? 14 : 24, x: 0, y: size == .compact ? 8 : 14)
    }
}

public struct SBSignatureHero<Actions: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let mode: SBHeroMode
    let size: SBHeroSize
    let actions: () -> Actions
    let footer: () -> Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLive = false

    public init(
        eyebrow: String,
        title: String,
        message: String,
        icon: String,
        tint: Color = SBColors.blue,
        mode: SBHeroMode = .progress,
        size: SBHeroSize = .full,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.mode = mode
        self.size = size
        self.actions = actions
        self.footer = footer
    }

    private var iconTileSize: CGFloat { size == .compact ? 44 : 58 }
    private var iconTileRadius: CGFloat { size == .compact ? 13 : 17 }
    private var cornerRadius: CGFloat { size == .compact ? 18 : 24 }
    private var padding: CGFloat { size == .compact ? SBSpacing.lg : SBSpacing.xl }

    public var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? SBSpacing.md : SBSpacing.lg) {
            HStack(alignment: .top, spacing: SBSpacing.md) {
                SBIconTile(icon: icon, tint: tint, size: iconTileSize, radius: iconTileRadius)
                    .scaleEffect(isLive && !reduceMotion ? 1.025 : 1)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: isLive)

                VStack(alignment: .leading, spacing: size == .compact ? 4 : 7) {
                    Text(eyebrow)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(tint)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    Text(title)
                        .font(size == .compact ? SBTypography.heading3 : SBTypography.heading2)
                        .foregroundStyle(SBColors.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(size == .compact ? SBTypography.bodySmall : SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            actions()
            footer()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [SBColors.white.opacity(0.96), tint.opacity(0.20), SBColors.softLine],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: tint.opacity(0.14), radius: size == .compact ? 16 : 28, x: 0, y: size == .compact ? 8 : 16)
        .shadow(color: SBColors.navy.opacity(0.05), radius: 4, x: 0, y: 2)
        .onAppear { isLive = true }
    }

    private var heroBackground: some View {
        ZStack {
            switch mode {
            case .action:
                LinearGradient(
                    colors: [
                        tint.opacity(0.08),
                        SBColors.white,
                        SBColors.field.opacity(0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .progress:
                LinearGradient(
                    colors: [
                        tint.opacity(0.12),
                        SBColors.white,
                        SBColors.field.opacity(0.75)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .selection:
                LinearGradient(
                    colors: [
                        tint.opacity(0.06),
                        SBColors.field.opacity(0.92),
                        SBColors.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if mode != .action {
                Canvas { context, size in
                    var path = Path()
                    let spacing: CGFloat = 28
                    var x: CGFloat = -size.height
                    while x < size.width + size.height {
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        x += spacing
                    }
                    context.stroke(path, with: .color(tint.opacity(mode == .progress ? 0.055 : 0.035)), lineWidth: 1)
                }
            }

            LinearGradient(
                colors: [SBColors.white.opacity(0.72), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

public struct SBCommandCard<Content: View>: View {
    let tint: Color
    let action: () -> Void
    let content: () -> Content

    public init(
        tint: Color = SBColors.blue,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            SBCard(radius: 18, borderColor: tint.opacity(0.12)) {
                content()
            }
        }
        .buttonStyle(PressableCardStyle())
    }
}

public struct SBMetricRibbon: View {
    let items: [Item]

    public struct Item: Identifiable {
        public let id = UUID()
        let icon: String
        let value: String
        let label: String
        let tint: Color

        public init(icon: String, value: String, label: String, tint: Color = SBColors.blue) {
            self.icon = icon
            self.value = value
            self.label = label
            self.tint = tint
        }
    }

    public init(items: [Item]) {
        self.items = items
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .sbScaledFont(size: 13, weight: .semibold)
                            .foregroundStyle(item.tint)
                            .frame(width: 24, height: 24)
                            .background(item.tint.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 7))

                        Text(item.value)
                            .font(SBTypography.titleMedium)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Text(item.label)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }
                .padding(SBSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SBColors.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(SBColors.softLine, lineWidth: 1)
                )
            }
        }
    }
}

public struct SBMetricTile: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    public init(icon: String, value: String, label: String, tint: Color = SBColors.blue) {
        self.icon = icon
        self.value = value
        self.label = label
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 13)
                .fill(tint.opacity(0.11))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .sbScaledFont(size: 17, weight: .semibold)
                        .foregroundStyle(tint)
                )

            Text(value)
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(label)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
        .shadow(color: SBColors.navy.opacity(0.045), radius: 10, x: 0, y: 6)
    }
}

public struct SBSectionHeader: View {
    let title: String
    let action: String?
    let onAction: (() -> Void)?

    public init(title: String, action: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.action = action
        self.onAction = onAction
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            Spacer()

            if let action, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(action)
                            .font(SBTypography.labelSmall)
                        Image(systemName: "chevron.right")
                            .sbScaledFont(size: 12, weight: .semibold)
                    }
                    .foregroundStyle(SBColors.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

public struct SBToolIconStrip: View {
    public struct Item: Identifiable {
        public let id = UUID()
        let icon: String
        let title: String
        let tint: Color
        let action: () -> Void

        public init(icon: String, title: String, tint: Color, action: @escaping () -> Void) {
            self.icon = icon
            self.title = title
            self.tint = tint
            self.action = action
        }
    }

    let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public var body: some View {
        HStack(spacing: SBSpacing.sm) {
            ForEach(items) { item in
                Button(action: item.action) {
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(item.tint.opacity(0.12))
                            .frame(width: 46, height: 46)
                            .overlay(
                                Image(systemName: item.icon)
                                    .sbScaledFont(size: 20, weight: .semibold)
                                    .foregroundStyle(item.tint)
                            )

                        Text(item.title)
                            .sbScaledFont(size: 10.5, weight: .semibold)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SBSpacing.md)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
        .shadow(color: SBColors.navy.opacity(0.045), radius: 10, x: 0, y: 6)
    }
}
