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
        workspaceStore.allFiles
            .flatMap { file in
                file.generated.prefix(1).map { output in (file: file, output: output) }
            }
            .prefix(3)
            .map { $0 }
    }

    private var activeBaseForceJobs: Int {
        workspaceStore.generationJobs.filter { job in
            SourceBaseQueueSurface.baseForce.includes(job.kind) && job.isActive
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "bolt.fill",
                        title: "BaseForce yükleniyor",
                        message: "Kaynaklar ve üretimler hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "BaseForce yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar Dene",
                        onAction: { Task { await loadWorkspace() } }
                    )
                } else {
                    heroSection.sbEntrance(0)
                    factoriesSection.sbEntrance(1)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(1180)
        }
        .sbPageBackground()
        .navigationTitle("BaseForce")
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
            title: "Bugün nasıl çalışacaksın?",
            message: readyFiles.isEmpty ? "Önce Drive'dan metni çıkarılmış bir kaynak seç." : "\(readyFiles.count) kaynak hazır. Ezber, test veya son tekrar seç.",
            icon: "bolt.fill",
            tint: SBColors.blue
        ) {
            SBButton(
                "Kaynak seç",
                icon: "folder",
                variant: .primary,
                size: .medium,
                action: { router.navigate(to: .sourcePicker) }
            )
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "square.stack.3d.up", value: "\(readyFiles.count)", label: "hazır", tint: SBColors.green),
                .init(icon: "clock.arrow.circlepath", value: "\(latestGenerations.count)", label: "son", tint: SBColors.orange)
            ])
        }
    }

    // MARK: - Factories Section

    private var factoriesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            sectionHeader(title: "Araçlar", action: nil) {}

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                factoryTile(
                    icon: "rectangle.on.rectangle",
                    title: "Flashcard",
                    subtitle: "Ezber ve aktif hatırlama",
                    color: SBColors.blue
                ) {
                    router.navigate(to: .flashcardFactory)
                }

                factoryTile(
                    icon: "questionmark.circle",
                    title: "Soru",
                    subtitle: "5 şıklı çözüm pratiği",
                    color: SBColors.green
                ) {
                    router.navigate(to: .questionFactory)
                }

                factoryTile(
                    icon: "doc.text",
                    title: "Son tekrar",
                    subtitle: "Komite öncesi hızlı tarama",
                    color: SBColors.purple
                ) {
                    router.navigate(to: .summaryFactory)
                }

                factoryTile(
                    icon: "arrow.triangle.branch",
                    title: "Akış",
                    subtitle: "Tanı, tedavi, algoritma",
                    color: SBColors.orange
                ) {
                    router.navigate(to: .algorithmFactory)
                }

                factoryTile(
                    icon: "tablecells",
                    title: "Tablo",
                    subtitle: "Benzer konuları ayır",
                    color: SBColors.cyan
                ) {
                    router.navigate(to: .comparisonFactory)
                }

                factoryTile(
                    icon: "clock",
                    title: "Kuyruk",
                    subtitle: activeBaseForceJobs == 0 ? "Hazırlananları izle" : "\(activeBaseForceJobs) çıktı hazırlanıyor",
                    color: SBColors.blue
                ) {
                    router.navigate(to: .queue(surface: .baseForce))
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
                        .sbScaledFont(size: 13, weight: .bold)
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

    // MARK: - Recent Sources Section

    private var recentSourcesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            sectionHeader(title: "Son Kaynaklar", action: "Tümünü Gör") {
                router.navigate(to: .sourcePicker)
            }

            SBCard(padding: 0, radius: 16) {
                if readyFiles.isEmpty {
                    SBEmptyState(
                        icon: "folder.badge.plus",
                        title: "Henüz üretime hazır kaynak yok",
                        message: "BaseForce çıktısı üretmek için önce Drive'a metin içeren PDF, PPTX, DOCX, PPT veya DOC yükle.",
                        badges: ["PDF", "PPTX", "Hazır kaynak"],
                        actionLabel: "Kaynak seç",
                        onAction: { router.navigate(to: .sourcePicker) }
                    )
                } else {
                    VStack(spacing: SBSpacing.md) {
                        ForEach(Array(readyFiles.prefix(3)), id: \.id) { file in
                            SBFileCard(
                                title: file.title,
                                kind: SBFileKind.from(file.kind),
                                status: SBStatus.from(file.status),
                                sizeLabel: file.sizeLabel,
                                courseTitle: file.courseTitle,
                                updatedLabel: file.updatedLabel
                            ) {
                                router.navigate(to: .sourcePicker)
                            }
                        }
                    }
                    .padding(SBSpacing.md)
                }
            }
        }
    }

    // MARK: - Recent Generations Section

    private var recentGenerationsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            sectionHeader(title: "Son Üretimler", action: "Tümünü Gör") {
                router.navigate(to: .queue(surface: .baseForce))
            }

            if latestGenerations.isEmpty {
                SBEmptyState(
                    icon: "rectangle.stack.badge.plus",
                    title: "Henüz üretim yok",
                    message: "Bir kaynak seçip üretim modlarından birini başlattığında sonuçların burada görünür.",
                    badges: ["Flashcard", "Soru", "Özet"],
                    actionLabel: "Üretime başla",
                    onAction: { router.navigate(to: .sourcePicker) }
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
                        "Detayı aç",
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
                                router.navigate(to: .queue(surface: .baseForce))
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, action: String?, onAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            Spacer()

            if let action {
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(action)
                            .font(SBTypography.labelSmall)
                        Image(systemName: "chevron.right")
                            .sbScaledFont(size: 12, weight: .semibold)
                    }
                    .foregroundStyle(SBColors.blue)
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
        case .summary, .examMorningSummary: return SBColors.purple
        case .algorithm: return SBColors.orange
        case .comparison, .table: return SBColors.blue
        case .clinicalScenario: return SBColors.orange
        case .learningPlan: return SBColors.green
        case .podcast: return SBColors.red
        case .infographic: return SBColors.cyan
        case .mindMap: return SBColors.purple
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
