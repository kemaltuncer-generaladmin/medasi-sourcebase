import SwiftUI
import SourceBaseBackend

struct BaseForceHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var router: AppRouter { appState.router }

    /// Discipline-tailored tool menu (order/labels/hero) for the signed-in student.
    private var profile: DisciplineOptionProfile {
        DisciplineOptionProfile.profile(for: AuthBackend.shared.currentProfile()?.department)
    }

    private var readyFiles: [DriveFile] {
        workspaceStore.readyFiles
    }

    private var latestGenerations: [(file: DriveFile, output: GeneratedOutput)] {
        Array(workspaceStore.latestGeneratedPairs.prefix(3))
    }

    private var activeBaseForceJobs: Int {
        workspaceStore.generationJobs.filter { job in
            SourceBaseQueueSurface.all.includes(job.kind) && job.isActive
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "bolt.fill",
                        title: "Üret yükleniyor",
                        message: "Kaynaklar ve üretimler hazırlanıyor...",
                        context: .baseForce
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Üret yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadWorkspace() } },
                        context: .baseForce
                    )
                } else {
                    heroSection.sbEntrance(0)
                    productionToolsSection.sbEntrance(1)
                    quickContinueSection.sbEntrance(2)
                    recentGenerationsSection.sbEntrance(3)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(1180)
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle("Üret")
        .sbOpaqueNavBar()
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Hazır kaynaklarını çalışma materyaline dönüştür.")
                .font(SBTypography.heading3)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)

            Text(profile.heroSubtitle)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SBSpacing.xs)
    }

    private var quickContinueSection: some View {
        Group {
            if let entry = workspaceStore.quickContinueOutput {
                SBQuickContinueSurface(
                    eyebrow: "Kaldığın yer",
                    title: entry.output.title,
                    message: "Son çalışmana kaldığın yerden dön.",
                    metadata: "\(entry.file.courseTitle) • \(entry.output.updatedLabel)",
                    actionLabel: "Aç",
                    icon: SBOutputStyle.outputIcon(entry.output.kind),
                    tint: SBOutputStyle.outputColor(entry.output.kind)
                ) {
                    router.navigate(to: .studyOutput(outputId: entry.output.id))
                }
            } else if let file = workspaceStore.quickContinueReadyFile {
                SBQuickContinueSurface(
                    eyebrow: "Kaldığın yer",
                    title: file.title,
                    message: "Hazır kaynak seçili. Üretim modunu seçip hemen başlayabilirsin.",
                    metadata: "\(file.courseTitle) • \(file.updatedLabel)",
                    actionLabel: "Bu kaynakla üret",
                    icon: "doc.text",
                    tint: SBColors.cyan
                ) {
                    openSourcePicker(with: file)
                }
            }
        }
    }

    private var productionToolsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            SBSectionHeader(title: "Üretim türleri")

            toolGroup(title: "Ana", tools: mainTools)
            toolGroup(title: "Görsel ve sesli üretim", tools: deepTools)
        }
    }

    private func toolGroup(title: String, tools: [ProductionTool]) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text(title)
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.muted)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                ForEach(tools) { tool in
                    factoryTile(
                        icon: tool.icon,
                        title: tool.title,
                        subtitle: tool.subtitle,
                        color: tool.color
                    ) {
                        if tool.isDeepTool {
                            openDeepTool(tool.route)
                        } else {
                            openFactory(tool.route)
                        }
                    }
                }
            }
        }
    }

    private var mainTools: [ProductionTool] {
        var tools = profile.mainKinds.map { tool in
            ProductionTool(
                icon: tool.icon,
                title: tool.title,
                subtitle: tool.subtitle,
                color: SBOutputStyle.outputColor(tool.kind),
                route: tool.kind.factoryRoute
            )
        }
        tools.append(
            ProductionTool(
                icon: "clock",
                title: "Üretim Kuyruğu",
                subtitle: activeBaseForceJobs == 0 ? "Başlayan üretimleri takip et" : "\(activeBaseForceJobs) üretim hazırlanıyor",
                color: SBColors.blue,
                route: .queue(surface: .all)
            )
        )
        return tools
    }

    private var deepTools: [ProductionTool] {
        profile.deepKinds.map { tool in
            ProductionTool(
                icon: tool.icon,
                title: tool.title,
                subtitle: tool.subtitle,
                color: SBOutputStyle.outputColor(tool.kind),
                route: tool.kind.deepRoute,
                isDeepTool: true
            )
        }
    }

    private func factoryTile(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        SBCommandCard(tint: color, action: action) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack {
                    SBIconTile(icon: icon, tint: color, size: 42, radius: 12)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .sbScaledFont(size: 13, weight: .semibold)
                        .foregroundStyle(SBColors.softText)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }
                .frame(minHeight: 42, alignment: .top)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Aracı aç")
    }

    // MARK: - Recent Generations Section

    private var recentGenerationsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            SBSectionHeader(title: "Son çalışmalar", action: "Tümünü gör") {
                router.navigate(to: .queue(surface: .all))
            }

            if latestGenerations.isEmpty {
                SBEmptyState(
                    icon: "rectangle.stack.badge.plus",
                    title: "Henüz çalışma yok",
                    message: "Bir kaynak seçip çalışma başlattığında burada görünür.",
                    badges: ["Flashcard", "Soru", "Özet"],
                    actionLabel: "Başla",
                    onAction: { openSourcePicker() },
                    context: .baseForce
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: SBSpacing.md)], spacing: SBSpacing.md) {
                    ForEach(latestGenerations, id: \.output.id) { entry in
                        generationCard(file: entry.file, output: entry.output)
                    }
                }
            }
        }
    }

    private func generationCard(file: DriveFile, output: GeneratedOutput) -> some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SBOutputStyle.outputColor(output.kind).opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: SBOutputStyle.outputIcon(output.kind))
                            .sbScaledFont(size: 18)
                            .foregroundStyle(SBOutputStyle.outputColor(output.kind))
                    }

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(SBOutputStyle.outputKindLabel(output.kind))
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(1)

                        Text(file.title)
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

                Text(output.updatedLabel)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.softText)

                HStack(spacing: SBSpacing.sm) {
                    SBButton(
                        "Aç",
                        icon: "arrow.up.right.square",
                        variant: .primary,
                        size: .small,
                        action: {
                            router.navigate(to: .studyOutput(outputId: output.id))
                        }
                    )

                    SBButton(
                        "Tekrar üret",
                        icon: "arrow.clockwise",
                        variant: .secondary,
                        size: .small,
                        action: {
                            Task {
                                _ = await workspaceStore.enqueueDriveGeneration(file: file, kind: output.kind)
                                router.navigate(to: .queue(surface: .all))
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func openSourcePicker(with file: DriveFile) {
        workspaceStore.setSelectedSources([file.id])
        workspaceStore.selectFile(file)
        router.beginSourceSelection(from: .baseForce, destination: .baseForceHome)
    }

    private func openSourcePicker() {
        router.beginSourceSelection(from: .baseForce, destination: .baseForceHome)
    }

    private func openFactory(_ route: AppRoute) {
        if case .queue = route {
            router.navigate(to: route)
            return
        }

        if workspaceStore.selectedReadyFiles.isEmpty {
            router.beginSourceSelection(from: .baseForce, destination: .route(route))
        } else {
            router.navigate(to: route)
        }
    }

    // Deep/clinical tools manage their own source selection inside the tool
    // view (as the old SourceLab tab did), so navigate straight there.
    private func openDeepTool(_ route: AppRoute) {
        router.navigate(to: route)
    }

    // MARK: - Actions

    private func loadWorkspace() async {
        isLoading = true
        errorMessage = nil
        await workspaceStore.loadWorkspace()
        errorMessage = workspaceStore.errorMessage
        isLoading = false
    }
}

private struct ProductionTool: Identifiable {
    var id: AppRoute { route }
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let route: AppRoute
    var isDeepTool = false
}

private extension SBGenerationJob {
    var isActive: Bool {
        switch status {
        case .queued, .running:
            return true
        case .completed, .failed:
            return false
        }
    }
}

#Preview {
    NavigationStack {
        BaseForceHomeView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
