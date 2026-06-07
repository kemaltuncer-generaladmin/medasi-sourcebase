import SwiftUI
import Pow

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var router = AppRouter.shared
    @Namespace private var tabNS

    private let tabs: [MainTabItem] = [
        MainTabItem(route: .drive, title: "Drive", icon: "folder", selectedIcon: "folder.fill"),
        MainTabItem(route: .baseForce, title: "Üret", icon: "bolt", selectedIcon: "bolt.fill"),
        MainTabItem(route: .centralAI, title: "MedasiChat", icon: "text.bubble", selectedIcon: "text.bubble.fill"),
        MainTabItem(route: .profile, title: "Profil", icon: "person", selectedIcon: "person.fill")
    ]

    var body: some View {
        @Bindable var router = router

        ZStack {
            SBAmbientBackground()
            currentTab
                .safeAreaPadding(.bottom, 96)
        }
        .safeAreaInset(edge: .bottom) {
            tabBar(selection: $router.selectedTab)
        }
        .task {
            await appState.workspace.loadWorkspace()
        }
    }

    @ViewBuilder
    private var currentTab: some View {
        switch router.selectedTab {
        case .drive:
            DriveHomeView()
        case .baseForce, .sourceLab:
            BaseForceHomeView()
        case .centralAI:
            CentralAIView()
        case .profile:
            ProfileView()
        default:
            DriveHomeView()
        }
    }

    private func tabBar(selection: Binding<AppRoute>) -> some View {
        HStack(spacing: 6) {
            ForEach(tabs) { item in
                tabButton(item, selection: selection)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(SBColors.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(SBColors.white.opacity(0.18))
                )
                .overlay(
                    // top highlight + hairline border for a raised glass edge
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [SBColors.white.opacity(0.9), SBColors.softLine.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: SBColors.navy.opacity(0.16), radius: 28, x: 0, y: 14)
                .shadow(color: SBColors.navy.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: horizontalSizeClass == .regular ? 620 : nil)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .background(
            SBColors.page
                .opacity(0.96)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ item: MainTabItem, selection: Binding<AppRoute>) -> some View {
        let isSelected = selection.wrappedValue == item.route

        return Button {
            SBHaptics.selection()
            if reduceMotion {
                router.switchTab(to: item.route)
            } else {
                withAnimation(SBMotion.spring) {
                    router.switchTab(to: item.route)
                }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .sbScaledFont(size: 19, weight: .semibold)
                    .frame(width: 34, height: 28)
                    .scaleEffect(!reduceMotion && isSelected ? 1.12 : 1)
                    .symbolEffect(.bounce, value: reduceMotion ? false : isSelected)

                Text(item.title)
                    .sbScaledFont(size: 10, weight: isSelected ? .semibold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? SBColors.blue : SBColors.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        selectedTabPill
                    }
                }
            )
            .changeEffect(.shine(duration: 0.55), value: router.selectedTab, isEnabled: isSelected && !reduceMotion)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(isSelected ? "Seçili" : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectedTabPill: some View {
        let pill = RoundedRectangle(cornerRadius: 14)
            .fill(SBColors.selectedBlue)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(SBColors.blue.opacity(0.16), lineWidth: 1)
            )

        if reduceMotion {
            pill
        } else {
            pill.matchedGeometryEffect(id: "tabPill", in: tabNS)
        }
    }
}

private struct MainTabItem: Identifiable {
    let route: AppRoute
    let title: String
    let icon: String
    let selectedIcon: String

    var id: AppRoute { route }
}

#Preview {
    MainTabView()
        .environment(AppState.shared)
        .environment(SourceBaseWorkspaceStore.shared)
}
