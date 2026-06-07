import SwiftUI

enum BaseForceFactoryStyle {
    static let screenSpacing = SBSpacing.lg
    static let pagePadding = SBSpacing.lg
    static let panelSpacing = SBSpacing.md
    static let settingsSpacing = SBSpacing.lg
    static let controlSpacing = SBSpacing.sm
    static let panelRadius: CGFloat = 16
    static let nestedPanelRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10
    static let chipRadius: CGFloat = 8
    static let iconTileSize: CGFloat = 42
    static let iconTileRadius: CGFloat = 12
    static let addIconTileSize: CGFloat = 44
    static let addIconTileRadius: CGFloat = 13

    @MainActor
    static func panel<Content: View>(
        spacing: CGFloat = panelSpacing,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SBCard(
            padding: SBSpacing.cardPadding,
            radius: panelRadius,
            backgroundColor: SBColors.white,
            borderColor: SBColors.softLine
        ) {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        }
    }

    @MainActor
    static func nestedPanel<Content: View>(
        borderColor: Color = SBColors.softLine,
        spacing: CGFloat = panelSpacing,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SBCard(
            padding: SBSpacing.cardPadding,
            radius: nestedPanelRadius,
            backgroundColor: SBColors.white,
            borderColor: borderColor
        ) {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        }
    }

    @MainActor
    static func sourceRequiredPanel<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        nestedPanel(borderColor: SBColors.blue.opacity(0.2), content: content)
    }
}
