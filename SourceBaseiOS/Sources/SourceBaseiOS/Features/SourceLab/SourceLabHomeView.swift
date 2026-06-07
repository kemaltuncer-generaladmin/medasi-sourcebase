import SwiftUI
import SourceBaseBackend

struct SourceLabHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @AppStorage("sourceLab.lastQuickTool") private var lastQuickToolRawValue = SourceLabQuickTool.clinical.rawValue
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var router: AppRouter { appState.router }
    private var quickTool: SourceLabQuickTool { SourceLabQuickTool(rawValue: lastQuickToolRawValue) ?? .clinical }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }
    private var readyCount: Int { workspaceStore.allFiles.filter { workspaceStore.isReadyForGeneration($0) }.count }
    private var activeSourceLabJobs: Int {
        workspaceStore.generationJobs.filter { job in
            SourceBaseQueueSurface.sourceLab.includes(job.kind) && isActive(job.status)
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "flask",
                        title: "SourceLab yükleniyor",
                        message: "Araçlar hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadWorkspace() } }
                    )
                } else {
                    quickStartHero.sbEntrance(0)
                    toolsSection.sbEntrance(1)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(1180)
        }
        .sbPageBackground()
        .sbInlineNavTitle()
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: SBSpacing.xs) {
                Text("SourceLab")
                    .font(SBTypography.heading1)
                    .foregroundStyle(SBColors.navy)

                Text("Bir kaynak seç, aracı çalıştır.")
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
            }

            Spacer()

            Button {
                router.navigate(to: .search)
            } label: {
                Image(systemName: "magnifyingglass")
                    .sbScaledFont(size: 20, weight: .semibold)
                    .foregroundStyle(SBColors.navy)
                    .frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - Quick Start Hero

    private var quickStartHero: some View {
        SBSignatureHero(
            eyebrow: "Derin çalışma",
            title: "Klinik tekrar araçları",
            message: selectedSources.isEmpty ? "Hazır bir kaynak seç, sonra vaka, plan veya görsel tekrar üret." : "\(selectedSources.count) kaynak seçili. Klinik ve uzun tekrar araçlarını aç.",
            icon: "flask.fill",
            tint: SBColors.purple
        ) {
            HStack(spacing: SBSpacing.sm) {
                SBButton(
                    selectedSources.isEmpty ? "Kaynak seç" : quickTool.ctaLabel,
                    icon: selectedSources.isEmpty ? "plus" : quickTool.icon,
                    variant: .primary,
                    size: .medium,
                    fullWidth: true,
                    action: {
                        if selectedSources.isEmpty {
                            router.navigate(to: .sourcePicker)
                        } else {
                            router.navigate(to: quickTool.route)
                        }
                    }
                )
                .accessibilityHint(selectedSources.isEmpty ? "Hazır kaynak seçme ekranını açar" : "\(quickTool.title) aracını açar")
                SBButton(
                    "Kuyruk",
                    icon: "clock",
                    variant: .secondary,
                    size: .medium,
                    action: { router.navigate(to: .queue(surface: .sourceLab)) }
                )
            }
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "checkmark.seal", value: "\(readyCount)", label: "hazır", tint: SBColors.green),
                .init(icon: "sparkles", value: "\(selectedSources.count)", label: "seçili", tint: SBColors.purple),
                .init(icon: "clock", value: "\(activeSourceLabJobs)", label: "aktif", tint: SBColors.orange)
            ])
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Araçlar")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: SBSpacing.md)], spacing: SBSpacing.md) {
                toolCard(
                    icon: "clock",
                    title: "Kuyruk",
                    subtitle: activeSourceLabJobs == 0 ? "Hazırlanan çalışmaları izle." : "\(activeSourceLabJobs) çıktı hazırlanıyor.",
                    color: SBColors.orange
                ) {
                    router.navigate(to: .queue(surface: .sourceLab))
                }

                toolCard(
                    icon: "bolt",
                    title: "Sınav Sabahı",
                    subtitle: "7 dakikalık kritik tarama.",
                    color: SBColors.orange
                ) {
                    openTool(.examMorning)
                }

                toolCard(
                    icon: "cross.case",
                    title: "Klinik Senaryo",
                    subtitle: "Ayırıcı tanı ve karar pratiği.",
                    color: SBColors.purple
                ) {
                    openTool(.clinical)
                }

                toolCard(
                    icon: "checklist",
                    title: "Öğrenme Planı",
                    subtitle: "Bugün, 72 saat ve 7 gün.",
                    color: SBColors.green
                ) {
                    openTool(.plan)
                }

                toolCard(
                    icon: "mic",
                    title: "Podcast",
                    subtitle: "Yolda dinlenecek tekrar.",
                    color: SBColors.purple
                ) {
                    openTool(.podcast)
                }

                toolCard(
                    icon: "chart.bar.doc.horizontal",
                    title: "İnfografik",
                    subtitle: "Tek bakışlık görsel hafıza.",
                    color: SBColors.cyan
                ) {
                    openTool(.infographic)
                }

                toolCard(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "Zihin Haritası",
                    subtitle: "Kavram ilişkilerini ayır.",
                    color: SBColors.blue
                ) {
                    openTool(.mindMap)
                }
            }
        }
    }

    private func toolCard(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        SBCommandCard(tint: color, action: action) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: icon, tint: color, size: 46, radius: 14)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
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
                        .sbScaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(SBColors.softText)
                        .accessibilityHidden(true)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Aracı aç")
    }

    // MARK: - Helpers

    private func openTool(_ tool: SourceLabQuickTool) {
        lastQuickToolRawValue = tool.rawValue
        router.navigate(to: tool.route)
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
        case .queued, .running:
            return true
        case .completed, .failed:
            return false
        }
    }

    private enum SourceLabQuickTool: String {
        case examMorning
        case clinical
        case plan
        case podcast
        case infographic
        case mindMap

        var title: String {
            switch self {
            case .examMorning: return "Sınav Sabahı"
            case .clinical: return "Klinik Senaryo"
            case .plan: return "Öğrenme Planı"
            case .podcast: return "Podcast"
            case .infographic: return "İnfografik"
            case .mindMap: return "Zihin Haritası"
            }
        }

        var ctaLabel: String {
            switch self {
            case .examMorning: return "Sınav Sabahı oluştur"
            case .clinical: return "Klinik Senaryo oluştur"
            case .plan: return "Öğrenme Planı oluştur"
            case .podcast: return "Podcast oluştur"
            case .infographic: return "İnfografik oluştur"
            case .mindMap: return "Zihin Haritası oluştur"
            }
        }

        var icon: String {
            switch self {
            case .examMorning: return "bolt"
            case .clinical: return "cross.case"
            case .plan: return "checklist"
            case .podcast: return "mic"
            case .infographic: return "chart.bar.doc.horizontal"
            case .mindMap: return "point.3.connected.trianglepath.dotted"
            }
        }

        var route: AppRoute {
            switch self {
            case .examMorning: return .examMorning
            case .clinical: return .clinical
            case .plan: return .plan
            case .podcast: return .podcast
            case .infographic: return .infographic
            case .mindMap: return .mindMap
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
