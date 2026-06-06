import SwiftUI
import SourceBaseBackend
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ResultView: View {
    let jobId: String

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var result: GenerationResult?
    @State private var saveError: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var didForwardToStudy = false
    @State private var didStartMonitoring = false

    private var router: AppRouter { appState.router }

    struct GenerationResult {
        let kind: GeneratedKind
        let title: String
        let sourceFileId: String
        let sourceTitle: String
        let createdAtLabel: String?
        let mcCostLabel: String?
        let contentText: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "checkmark.seal",
                        title: "Sonuç yükleniyor",
                        message: "Üretim sonucu hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Sonuç yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar Dene",
                        onAction: { Task { await monitorResult(force: true) } }
                    )
                } else {
                    if let result {
                        headerHero(result).sbEntrance(0)
                        resultPreviewCard(result).sbEntrance(0)
                        if !result.contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            RichResultContentView(
                                kind: result.kind,
                                title: result.title,
                                sourceTitle: result.sourceTitle,
                                contentText: result.contentText
                            )
                            .sbEntrance(1)
                        } else {
                            emptyContentCard.sbEntrance(1)
                        }
                        if let saveError {
                            saveErrorNotice(saveError)
                        }
                        quickActionsSection.sbEntrance(2)
                        primaryActionButton.sbEntrance(3)
                    } else {
                        headerSection
                        emptyState
                        nextStepButton
                    }
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground()
        .navigationTitle(result?.title ?? "Üretim Sonucu")
        .sbInlineNavTitle()
        .task {
            await monitorResult()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.xs) {
            if let result {
                Text(result.sourceTitle)
            } else {
                Text("Sonuç burada görünür.")
            }
        }
        .font(SBTypography.bodyMedium)
        .foregroundStyle(SBColors.muted)
    }

    private func headerHero(_ result: GenerationResult) -> some View {
        SBSignatureHero(
            eyebrow: "Sonuç",
            title: outputKindLabel(result.kind),
            message: result.sourceTitle,
            icon: outputIcon(result.kind),
            tint: outputColor(result.kind)
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "checkmark.seal.fill", value: "Hazır", label: "durum", tint: SBColors.green),
                .init(icon: "doc.text", value: outputKindLabel(result.kind), label: "tür", tint: outputColor(result.kind)),
                .init(icon: "creditcard", value: result.mcCostLabel ?? "Güvenli", label: "MC", tint: SBColors.orange)
            ])
        }
    }

    // MARK: - Result Preview Card

    private func resultPreviewCard(_ result: GenerationResult) -> some View {
        SBCommandCard(tint: outputColor(result.kind), action: openCollections) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: outputIcon(result.kind), tint: outputColor(result.kind), size: 46, radius: 13)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(outputKindLabel(result.kind))
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)

                        Text(result.sourceTitle)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    SBStatusBadge(status: .ready, compact: true)
                }

                Text(previewText(result.contentText))
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(4)

                HStack {
                    Text(result.createdAtLabel ?? "Bugün")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.softText)

                    Spacer()

                    SBButton(
                        "Koleksiyonda aç",
                        icon: "rectangle.stack",
                        variant: .primary,
                        size: .small,
                        action: openCollections
                    )

                    SBButton(
                        "Tekrar üret",
                        icon: "arrow.clockwise",
                        variant: .secondary,
                        size: .small,
                        action: regenerate
                    )
                }
            }
        }
    }

    // MARK: - Content View

    private var emptyContentCard: some View {
        SBCard(radius: 16) {
            VStack(spacing: SBSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .sbScaledFont(size: 32)
                    .foregroundStyle(SBColors.orange)

                Text("Boş içerik döndü")
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)

                Text("Yeniden üretmeyi deneyebilirsin.")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(SBSpacing.xl)
        }
    }

    // MARK: - Output Structure

    // MARK: - Save Error Notice

    private func saveErrorNotice(_ error: String) -> some View {
        SBCard(radius: 14) {
            VStack(spacing: SBSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .sbScaledFont(size: 28)
                    .foregroundStyle(SBColors.orange)

                Text("Sonuç görüntülendi")
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)

                Text("Koleksiyon bağlantısı yenilenemedi. Koleksiyonları açıp listeyi yenileyebilirsin.\n\(error)")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(SBSpacing.md)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Sonraki adımlar")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            if result != nil {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.md)], spacing: SBSpacing.md) {
                    quickAction(icon: "doc.on.doc", label: "Kopyala", color: SBColors.green, action: export)
                    quickAction(icon: "doc.text.magnifyingglass", label: "Kaynağa dön", color: SBColors.orange, action: openSource)
                    quickAction(icon: "arrow.triangle.2.circlepath", label: "Tekrar üret", color: SBColors.purple, action: regenerate)
                }
            }
        }
    }

    private func quickAction(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        SBCommandCard(tint: color, action: action) {
            VStack(spacing: SBSpacing.sm) {
                SBIconTile(icon: icon, tint: color, size: 56, radius: 14)

                Text(label)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.navy)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(label.replacingOccurrences(of: "\n", with: " "))
    }

    // MARK: - Primary Action Button

    private var primaryActionButton: some View {
        SBButton(
            "Koleksiyonda aç",
            icon: "rectangle.stack",
            variant: .primary,
            size: .large,
            fullWidth: true,
            action: openCollections
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        SBCard {
            VStack(spacing: SBSpacing.md) {
                Image(systemName: "doc.text.magnifyingglass")
                    .sbScaledFont(size: 32)
                    .foregroundStyle(SBColors.blue)

                Text("Sonuç bekleniyor")
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)

                Text("Kaynağından bir çalışma çıktısı üretip burada görüntüleyebilirsin.")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(SBSpacing.xl)
        }
    }

    // MARK: - Next Step Button

    private var nextStepButton: some View {
        SBButton(
            "Tekrar üretime dön",
            icon: "arrow.triangle.2.circlepath",
            variant: .primary,
            size: .large,
            fullWidth: true,
            action: regenerate
        )
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
        case .summary: return SBColors.purple
        case .examMorningSummary: return SBColors.purple
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

    private func previewText(_ content: String) -> String {
        let cleaned = content
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return "Önizleme henüz hazır değil." }
        if cleaned.count <= 180 {
            return cleaned
        }
        return "\(cleaned.prefix(177).trimmingCharacters(in: .whitespaces))..."
    }

    private func openCollections() {
        saveError = nil
        router.navigate(to: .collections)
    }

    private func export() {
        guard let result else {
            workspaceStore.toast("Kopyalanacak sonuç yok.")
            return
        }
        let text = "\(result.title)\nKaynak: \(result.sourceTitle)\n\n\(result.contentText)"
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        workspaceStore.toast("Sonuç metni panoya kopyalandı.")
    }

    private func regenerate() {
        router.pop()
    }

    private func openSource() {
        guard let result else { return }
        router.navigate(to: .fileDetail(fileId: result.sourceFileId))
    }

    private func monitorResult(force: Bool = false) async {
        if didStartMonitoring && !force { return }
        didStartMonitoring = true
        if force {
            didForwardToStudy = false
            errorMessage = nil
        }

        for attempt in 0..<120 {
            if await loadResult() || didForwardToStudy {
                return
            }

            let shouldKeepPolling = workspaceStore.generationJobs.contains { job in
                (job.id == jobId || job.output?.jobId == jobId) && job.isActive
            }
            guard shouldKeepPolling || attempt < 3 else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        if !didForwardToStudy {
            isLoading = false
            errorMessage = "Üretim beklenenden uzun sürdü. Kuyruk ekranından takip edip hazır olduğunda sonucu açabilirsin."
        }
    }

    @discardableResult
    private func loadResult() async -> Bool {
        if result == nil {
            isLoading = true
        }
        errorMessage = nil
        await workspaceStore.loadWorkspace()
        if let output = findOutput() {
            forwardToStudy(output.id)
            return true
        } else if let job = workspaceStore.generationJobs.first(where: { $0.id == jobId || $0.output?.jobId == jobId }) {
            if let outputId = job.output?.id {
                forwardToStudy(outputId)
                return true
            }
            if let outputId = job.outputId, !outputId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                forwardToStudy(outputId)
                return true
            }

            if job.isCompleted {
                if let output = await workspaceStore.finalizeGenerationJob(job), !output.id.isEmpty {
                    forwardToStudy(output.id)
                    return true
                }
            }

            if let failureMessage = job.failureMessage {
                result = nil
                errorMessage = failureMessage
                isLoading = false
                return true
            }

            result = GenerationResult(
                kind: job.kind,
                title: job.output?.title ?? job.kind.titleLabel,
                sourceFileId: job.sourceFileId,
                sourceTitle: job.sourceTitle,
                createdAtLabel: job.output?.updatedLabel,
                mcCostLabel: nil,
                contentText: job.output?.contentText ?? job.output?.detail ?? progressText(for: job)
            )
        } else {
            result = nil
        }
        errorMessage = workspaceStore.errorMessage
        isLoading = false
        return false
    }

    private func forwardToStudy(_ outputId: String) {
        let trimmed = outputId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !didForwardToStudy else { return }
        didForwardToStudy = true
        isLoading = false
        router.replaceCurrent(with: .studyOutput(outputId: trimmed))
    }

    private func findOutput() -> GeneratedOutput? {
        for file in workspaceStore.allFiles {
            if let output = file.generated.first(where: { $0.jobId == jobId || $0.id == jobId }) {
                return output
            }
        }
        for bundle in workspaceStore.workspace.collections {
            if let output = bundle.outputs.first(where: { $0.jobId == jobId || $0.id == jobId }) {
                return output
            }
        }
        return nil
    }

    private func progressText(for job: SBGenerationJob) -> String {
        switch job.status {
        case .queued:
            return "Çalışma çıktısı kuyruğa alındı. Hazır olduğunda sonuç ekranına geçeceksin."
        case .running:
            return "Üretim devam ediyor • \(Int(job.progress * 100))%"
        case .completed:
            return "Üretim tamamlandı. Çalışma çıktısı kaydediliyor."
        case .failed(let message):
            return message
        }
    }
}

private extension SBGenerationJob {
    var isActive: Bool {
        switch status {
        case .queued, .running: return true
        case .completed, .failed: return false
        }
    }

    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let message) = status { return message }
        return nil
    }
}

#Preview {
    NavigationStack {
        ResultView(jobId: "test-job")
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
