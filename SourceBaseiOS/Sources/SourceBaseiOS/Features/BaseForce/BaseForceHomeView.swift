import SwiftUI
import SourceBaseBackend

struct BaseForceHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var router: AppRouter { appState.router }

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
                        title: "BaseForce yükleniyor",
                        message: "Kaynaklar ve üretimler hazırlanıyor...",
                        context: .baseForce
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "BaseForce yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadWorkspace() } },
                        context: .baseForce
                    )
                } else {
                    heroSection.sbEntrance(0)
                    quickContinueSection.sbEntrance(1)
                    momentumSection.sbEntrance(2)
                    primaryFactoriesSection.sbEntrance(3)
                    secondaryFactoriesSection.sbEntrance(4)
                    deepToolsSection.sbEntrance(5)
                    recentGenerationsSection.sbEntrance(6)
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.xs) {
            Text("Kaynaklarından sınav odaklı çalışma setleri üret.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        SBSignatureHero(
            eyebrow: "Çalışma setleri",
            title: "Hazır kaynakla hemen başla",
            message: readyFiles.isEmpty ? "Önce Drive'dan hazır bir kaynak seç." : "\(readyFiles.count) kaynak hazır. Önce kaynağını seç, sonra üretim türünü aç.",
            icon: "bolt.fill",
            tint: SBColors.blue,
            mode: .action
        ) {
            HStack(spacing: SBSpacing.sm) {
                SBButton(
                    "Kaynak seç",
                    icon: "folder",
                    variant: .primary,
                    size: .medium,
                    fullWidth: true,
                    action: { openSourcePicker() }
                )
                SBButton(
                    "Kuyruğu gör",
                    icon: "clock",
                    variant: .secondary,
                    size: .medium,
                    action: { router.navigate(to: .queue(surface: .all)) }
                )
            }
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "square.stack.3d.up", value: "\(readyFiles.count)", label: "hazır", tint: SBColors.green),
                .init(icon: "clock.arrow.circlepath", value: "\(latestGenerations.count)", label: "son", tint: SBColors.orange)
            ])
        }
    }

    private var quickContinueSection: some View {
        Group {
            if let entry = workspaceStore.quickContinueOutput {
                SBQuickContinueSurface(
                    eyebrow: "Kaldığın yer",
                    title: entry.output.title,
                    message: "Son ürettiğin çıktıya tek dokunuşla geri dön.",
                    metadata: "\(entry.file.courseTitle) • \(entry.output.updatedLabel)",
                    actionLabel: "Çıktıyı aç",
                    icon: outputIcon(entry.output.kind),
                    tint: outputColor(entry.output.kind)
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

    private var momentumSection: some View {
        SBWorkspaceMomentumRibbon(
            readyCount: readyFiles.count,
            outputCount: workspaceStore.totalGeneratedOutputCount,
            focusTitle: workspaceStore.momentumFocusTitle
        )
    }

    private var primaryFactoriesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            SBSectionHeader(title: "Hemen üret", action: readyFiles.isEmpty ? nil : "Kaynağı değiştir") {
                openSourcePicker()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                factoryTile(
                    icon: "rectangle.on.rectangle",
                    title: "Flashcard",
                    subtitle: "Hızlı tekrar kartları hazırla",
                    color: SBColors.blue
                ) {
                    openFactory(.flashcardFactory)
                }

                factoryTile(
                    icon: "questionmark.circle",
                    title: "Soru",
                    subtitle: "Klinik soru pratiğine geç",
                    color: SBColors.cyan
                ) {
                    openFactory(.questionFactory)
                }

                factoryTile(
                    icon: "doc.text",
                    title: "Son tekrar",
                    subtitle: "Kısa ve net özet al",
                    color: SBColors.purple
                ) {
                    openFactory(.summaryFactory)
                }
            }
        }
    }

    private var secondaryFactoriesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            SBSectionHeader(title: "Diğer araçlar")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                factoryTile(
                    icon: "arrow.triangle.branch",
                    title: "Akış",
                    subtitle: "Karar akışını sadeleştir",
                    color: SBColors.orange
                ) {
                    openFactory(.algorithmFactory)
                }

                factoryTile(
                    icon: "tablecells",
                    title: "Tablo",
                    subtitle: "Konuları yan yana kıyasla",
                    color: SBColors.purple
                ) {
                    openFactory(.comparisonFactory)
                }

                factoryTile(
                    icon: "clock",
                    title: "Kuyruk",
                    subtitle: activeBaseForceJobs == 0 ? "Hazırlananları takip et" : "\(activeBaseForceJobs) çıktı hazırlanıyor",
                    color: SBColors.blue
                ) {
                    router.navigate(to: .queue(surface: .all))
                }
            }
        }
    }

    // MARK: - Deep / clinical tools (merged from the old SourceLab tab)

    private var deepToolsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            SBSectionHeader(title: "Klinik & derin tekrar")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                factoryTile(
                    icon: "cross.case",
                    title: "Klinik Senaryo",
                    subtitle: "Ayırıcı tanı ve karar pratiği",
                    color: SBColors.purple
                ) {
                    openDeepTool(.clinical)
                }

                factoryTile(
                    icon: "bolt",
                    title: "Sınav Sabahı",
                    subtitle: "7 dakikalık kritik tarama",
                    color: SBColors.orange
                ) {
                    openDeepTool(.examMorning)
                }

                factoryTile(
                    icon: "checklist",
                    title: "Öğrenme Planı",
                    subtitle: "Bugün, 72 saat ve 7 gün",
                    color: SBColors.green
                ) {
                    openDeepTool(.plan)
                }

                factoryTile(
                    icon: "mic",
                    title: "Podcast",
                    subtitle: "Yolda dinlenecek tekrar",
                    color: SBColors.red
                ) {
                    openDeepTool(.podcast)
                }

                factoryTile(
                    icon: "chart.bar.doc.horizontal",
                    title: "İnfografik",
                    subtitle: "Tek bakışlık görsel hafıza",
                    color: SBColors.cyan
                ) {
                    openDeepTool(.infographic)
                }

                factoryTile(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "Zihin Haritası",
                    subtitle: "Kavram ilişkilerini ayır",
                    color: SBColors.blue
                ) {
                    openDeepTool(.mindMap)
                }
            }
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
            SBSectionHeader(title: "Son üretimler", action: "Tümünü gör") {
                router.navigate(to: .queue(surface: .all))
            }

            if latestGenerations.isEmpty {
                SBEmptyState(
                    icon: "rectangle.stack.badge.plus",
                    title: "Henüz üretim yok",
                    message: "Bir kaynak seçip üretim modlarından birini başlattığında sonuçların burada görünür.",
                    badges: ["Flashcard", "Soru", "Özet"],
                    actionLabel: "Üretime başla",
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
                            .fill(outputColor(output.kind).opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: outputIcon(output.kind))
                            .sbScaledFont(size: 18)
                            .foregroundStyle(outputColor(output.kind))
                    }

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(outputKindLabel(output.kind))
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
                        "Çıktıyı aç",
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

    private func outputIcon(_ kind: GeneratedKind) -> String {
        switch kind {
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

    private func outputColor(_ kind: GeneratedKind) -> Color {
        switch kind {
        case .flashcard: return SBColors.blue
        case .question: return SBColors.questionTint
        case .summary, .examMorningSummary, .comparison, .table, .mindMap: return SBColors.purple
        case .algorithm: return SBColors.orange
        case .clinicalScenario: return SBColors.orange
        case .learningPlan: return SBColors.green
        case .podcast: return SBColors.red
        case .infographic: return SBColors.cyan
        }
    }

    private func outputKindLabel(_ kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard: return "Flashcard"
        case .question: return "Soru"
        case .summary: return "Özet"
        case .examMorningSummary: return "Sınav Sabahı"
        case .algorithm: return "Algoritma"
        case .comparison, .table: return "Tablo"
        case .clinicalScenario: return "Klinik Senaryo"
        case .learningPlan: return "Öğrenme Planı"
        case .podcast: return "Podcast"
        case .infographic: return "İnfografik"
        case .mindMap: return "Zihin Haritası"
        }
    }

    private func openSourcePicker(with file: DriveFile) {
        workspaceStore.setSelectedSources([file.id])
        workspaceStore.selectFile(file)
        router.beginSourceSelection(from: .baseForce, destination: .baseForceHome)
    }

    private func openSourcePicker() {
        router.beginSourceSelection(from: .baseForce, destination: .baseForceHome)
    }

    private func openFactory(_ route: AppRoute) {
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
