import SwiftUI
import SourceBaseBackend

/// Pure, minimal production tools home: a clean tool grid, a slim source line,
/// and one queue entry point. No oversized hero, no metric clutter.
struct SourceLabHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var router: AppRouter { appState.router }
    private var selectedCount: Int { workspaceStore.selectedSourceIds.count }
    private var activeJobs: Int {
        workspaceStore.generationJobs.filter {
            SourceBaseQueueSurface.sourceLab.includes($0.kind) && isActive($0.status)
        }.count
    }

    /// Deep/media tools, ordered + labeled for the signed-in student's discipline.
    private var tools: [Tool] {
        DisciplineOptionProfile
            .profile(for: AuthBackend.shared.currentProfile()?.department)
            .deepKinds
            .map { tool in
                Tool(
                    kind: tool.kind,
                    title: tool.title,
                    subtitle: tool.subtitle,
                    icon: tool.icon,
                    tint: SBOutputStyle.outputColor(tool.kind)
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(icon: "flask", title: "Hazırlanıyor", message: "Araçlar yükleniyor.")
                } else if let error = errorMessage {
                    SBErrorState(title: "Yüklenemedi", message: error, actionLabel: "Tekrar dene", onAction: { Task { await loadWorkspace() } })
                } else {
                    header.sbEntrance(0)
                    sourceLine.sbEntrance(1)
                    grid.sbEntrance(2)
                }
            }
            .padding(SBSpacing.lg)
            .sbReadableWidth(720)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground()
        .sbInlineNavTitle()
        .task { await loadWorkspace() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Üretim Araçları")
                    .font(SBTypography.heading1)
                    .foregroundStyle(SBColors.navy)
                Text("Bir araç seç, kaynağından üret.")
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
            }
            Spacer()
            Button {
                SBHaptics.selection()
                router.navigate(to: .queue(surface: .all))
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "clock")
                        .sbScaledFont(size: 20, weight: .semibold)
                        .foregroundStyle(SBColors.navy)
                        .frame(width: 44, height: 44)
                    if activeJobs > 0 {
                        Text("\(activeJobs)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(SBColors.orange, in: Circle())
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .accessibilityLabel("Üretim Kuyruğu\(activeJobs > 0 ? ", \(activeJobs) aktif" : "")")
        }
    }

    @ViewBuilder
    private var sourceLine: some View {
        Button {
            SBHaptics.selection()
            router.navigate(to: .sourcePicker)
        } label: {
            HStack(spacing: SBSpacing.sm) {
                Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "doc.badge.plus")
                    .sbScaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(selectedCount > 0 ? SBColors.green : SBColors.purple)
                Text(selectedCount > 0 ? "\(selectedCount) kaynak seçili" : "Hazır bir kaynak seç")
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)
                Spacer()
                Text(selectedCount > 0 ? "Değiştir" : "Seç")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(SBColors.softText)
            }
            .padding(SBSpacing.md)
            .background(SBColors.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SBColors.softLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: SBSpacing.md), GridItem(.flexible(), spacing: SBSpacing.md)], spacing: SBSpacing.md) {
            ForEach(tools) { tool in
                toolCard(tool)
            }
        }
    }

    private func toolCard(_ tool: Tool) -> some View {
        Button {
            SBHaptics.selection()
            router.navigate(to: tool.route)
        } label: {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                SBIconTile(icon: tool.icon, tint: tool.tint, size: 46, radius: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                    Text(tool.subtitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(SBSpacing.md)
            .background(SBColors.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(tool.tint.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tool.title). \(tool.subtitle)")
        .accessibilityHint("Aracı aç")
    }

    private func loadWorkspace() async {
        isLoading = !workspaceStore.hasLoadedWorkspace
        errorMessage = nil
        await workspaceStore.loadWorkspace()
        errorMessage = workspaceStore.errorMessage
        isLoading = false
    }

    private func isActive(_ status: SBGenerationStatus) -> Bool {
        switch status {
        case .queued, .running: return true
        case .completed, .failed: return false
        }
    }

    private struct Tool: Identifiable {
        let kind: GeneratedKind
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        var id: String { kind.rawValue }
        var route: AppRoute {
            switch kind {
            case .examMorningSummary: return .examMorning
            case .clinicalScenario: return .clinical
            case .learningPlan: return .plan
            case .podcast: return .podcast
            case .infographic: return .infographic
            case .mindMap: return .mindMap
            default: return .examMorning
            }
        }
    }
}

#Preview {
    NavigationStack {
        SourceLabHomeView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
