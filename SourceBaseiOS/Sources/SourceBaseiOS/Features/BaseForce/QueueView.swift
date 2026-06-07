import SwiftUI
import SourceBaseBackend

struct QueueView: View {
    let surface: SourceBaseQueueSurface

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @StateObject private var cancellationService = SBJobCancellationService.shared
    @StateObject private var offlineQueue = SBOfflineQueueService.shared
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFilter: QueueFilter = .all

    private var router: AppRouter { appState.router }
    private var jobs: [JobState] {
        workspaceStore.generationJobs.filter { surface.includes($0.kind) }.map { job in
            let source = workspaceStore.file(id: job.sourceFileId)
            return JobState(
                id: job.output?.jobId ?? job.id,
                outputId: job.output?.id ?? job.outputId,
                sourceFileId: job.sourceFileId,
                sourceTitle: job.sourceTitle,
                sourceKind: source.map { SBFileKind.from($0.kind) } ?? .pdf,
                title: job.kind.titleLabel,
                kind: job.kind,
                status: queueStatus(from: job.status),
                progress: job.progress,
                errorMessage: {
                    if case .failed(let message) = job.status { return message }
                    return nil
                }()
            )
        }
    }

    init(surface: SourceBaseQueueSurface = .all) {
        self.surface = surface
    }

    struct JobState: Identifiable {
        let id: String
        let outputId: String?
        let sourceFileId: String
        let sourceTitle: String
        let sourceKind: SBFileKind
        let title: String
        let kind: GeneratedKind
        let status: JobStatus
        let progress: Double
        let errorMessage: String?
    }

    enum JobStatus {
        case pending, running, completed, failed
    }

    enum QueueFilter: String, CaseIterable {
        case all = "Hepsi"
        case preparing = "Hazırlanıyor"
        case ready = "Hazır"
        case failed = "Tekrar dene"

        var color: Color {
            switch self {
            case .all: return SBColors.blue
            case .preparing: return SBColors.blue
            case .ready: return SBColors.green
            case .failed: return SBColors.red
            }
        }
    }

    private var runningCount: Int {
        jobs.filter { $0.status == .pending || $0.status == .running }.count + offlineRequests.count
    }

    private var completedCount: Int {
        jobs.filter { $0.status == .completed }.count
    }

    private var failedCount: Int {
        jobs.filter { $0.status == .failed }.count
    }

    private var offlineRequests: [OfflineGenerationRequest] {
        guard selectedFilter == .all || selectedFilter == .preparing else { return [] }
        return offlineQueue.pendingRequests.filter { request in
            guard let kind = GeneratedKind(rawValue: request.kind) else { return surface == .all }
            return surface.includes(kind)
        }
    }

    private var filteredJobs: [JobState] {
        switch selectedFilter {
        case .all: return jobs
        case .preparing: return jobs.filter { $0.status == .pending || $0.status == .running }
        case .ready: return jobs.filter { $0.status == .completed }
        case .failed: return jobs.filter { $0.status == .failed }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(icon: "clock", title: "Kuyruk açılıyor", message: "Çalışmalar güncelleniyor.")
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadJobs() } }
                    )
                } else {
                    heroCard.sbEntrance(0)
                    filterBar.sbEntrance(1)
                    jobsList.sbEntrance(2)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle(surface.title)
        .task {
            await loadJobs()
            await pollActiveJobs()
        }
        .refreshable {
            await loadJobs()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        SBSignatureHero(
            eyebrow: surface.eyebrow,
            title: surface.title,
            message: surface.message,
            icon: surface.icon,
            tint: surface.tint,
            size: .compact
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "hourglass", value: "\(runningCount)", label: "aktif", tint: SBColors.blue),
                .init(icon: "checkmark.circle", value: "\(completedCount)", label: "hazır", tint: SBColors.green),
                .init(icon: "arrow.clockwise", value: "\(failedCount)", label: "tekrar", tint: SBColors.red)
            ])
        }
    }

    // MARK: - Metrics Grid

    // MARK: - Filter Bar

    private var filterBar: some View {
        FlowLayout(spacing: SBSpacing.sm) {
            ForEach(QueueFilter.allCases, id: \.self) { filter in
                filterChip(filter)
            }
        }
    }

    private func filterChip(_ filter: QueueFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            SBHaptics.selection()
            withAnimation(SBMotion.spring) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: SBSpacing.xs) {
                if filter != .all {
                    Circle()
                        .fill(filter.color)
                        .frame(width: 8, height: 8)
                }

                Text(filter.rawValue)
                    .font(SBTypography.labelSmall)
            }
            .foregroundStyle(isSelected ? .white : SBColors.navy)
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? filter.color : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? filter.color : SBColors.softLine, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Jobs List

    @ViewBuilder
    private var jobsList: some View {
        if filteredJobs.isEmpty && offlineRequests.isEmpty {
            SBCard {
                SBEmptyState(
                    icon: "clock.badge.questionmark",
                    title: "Henüz çalışma yok",
                    message: surface.emptyMessage,
                    badges: ["Başladı", "Hazırlanıyor", "Hazır", "Tekrar dene"]
                )
            }
        } else {
            LazyVStack(spacing: SBSpacing.md) {
                ForEach(offlineRequests) { request in
                    offlineRequestRow(request)
                }

                ForEach(filteredJobs) { job in
                    jobRow(job)
                }
            }
        }
    }

    private func offlineRequestRow(_ request: OfflineGenerationRequest) -> some View {
        SBCard(radius: 16, borderColor: SBColors.orange.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    SBIconTile(icon: "wifi.slash", tint: SBColors.orange, size: 40, radius: 12)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(GeneratedKind(rawValue: request.kind)?.titleLabel ?? "Üretim")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(1)

                        Text(request.fileTitle)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("Bağlantı bekliyor")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.orange)
                        .padding(.horizontal, SBSpacing.sm)
                        .padding(.vertical, SBSpacing.xs)
                        .background(SBColors.orange.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack {
                    Text("İnternet gelince üretim başlar.")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)

                    Spacer()

                    SBButton(
                        "Kaldır",
                        icon: "trash",
                        variant: .secondary,
                        size: .small,
                        action: { offlineQueue.cancelRequest(request.id) }
                    )
                }
            }
        }
    }

    private func jobRow(_ job: JobState) -> some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    SBIconTile(icon: SBOutputStyle.outputIcon(job.kind), tint: statusColor(job.status), size: 42, radius: 12)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(job.title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)

                        Text(job.sourceTitle)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    statusBadge(job.status)
                }

                if job.status == .running || job.status == .pending {
                    progressBar(job.progress)
                }

                if let errorMsg = job.errorMessage {
                    Text(queueErrorMessage(errorMsg))
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.red)
                }

                HStack {
                    Text(progressLabel(job))
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)

                    Spacer()

                    actionButton(job)
                }
            }
        }
    }

    private func statusBadge(_ status: JobStatus) -> some View {
        let label: String
        let color: Color

        switch status {
        case .pending:
            label = "Başladı"
            color = SBColors.blue
        case .running:
            label = "Hazırlanıyor"
            color = SBColors.blue
        case .completed:
            label = "Hazır"
            color = SBColors.green
        case .failed:
            label = "Tamamlanamadı"
            color = SBColors.red
        }

        return Text(label)
            .font(SBTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, SBSpacing.sm)
            .padding(.vertical, SBSpacing.xs)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(SBColors.softLine)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(SBColors.blue)
                    .frame(width: geometry.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }

    private func progressLabel(_ job: JobState) -> String {
        switch job.status {
        case .pending:
            return "Kuyruğa eklendi"
        case .running:
            return "Hazırlanıyor • \(Int(job.progress * 100))%"
        case .completed:
            return "Açmaya hazır"
        case .failed:
            return "Tekrar deneyebilirsin"
        }
    }

    private func actionButton(_ job: JobState) -> some View {
        Group {
            switch job.status {
            case .completed:
                SBButton(
                    "Detayı aç",
                    icon: "arrow.up.right.square",
                    variant: .primary,
                    size: .small,
                    action: {
                        if let outputId = job.outputId {
                            router.navigate(to: .studyOutput(outputId: outputId))
                        } else {
                            router.navigate(to: .result(jobId: job.id))
                        }
                    }
                )

            case .failed:
                SBButton(
                    "Tekrar dene",
                    icon: "arrow.clockwise",
                    variant: .secondary,
                    size: .small,
                    action: {
                        Task {
                            if let storeJob = workspaceStore.generationJobs.first(where: { $0.id == job.id || $0.output?.jobId == job.id }) {
                                await workspaceStore.retryJob(storeJob)
                                await workspaceStore.refreshGenerationQueue()
                            } else if let file = workspaceStore.file(id: job.sourceFileId) {
                                _ = await workspaceStore.enqueueDriveGeneration(file: file, kind: job.kind)
                                await workspaceStore.refreshGenerationQueue()
                            } else {
                                workspaceStore.toast("Kaynak bulunamadı. Drive'dan yeniden seç.")
                            }
                        }
                    }
                )

            case .pending, .running:
                let isCancelling = cancellationService.cancellingJobIds.contains(job.id)
                let cancelStatus = cancellationService.verificationStatus[job.id]
                
                VStack(spacing: SBSpacing.sm) {
                    SBButton(
                        isCancelling ? "İptal ediliyor..." : "İptal",
                        icon: "xmark",
                        variant: .secondary,
                        size: .small,
                        isLoading: isCancelling,
                        action: {
                            Task {
                                if let storeJob = workspaceStore.generationJobs.first(where: { $0.id == job.id || $0.output?.jobId == job.id }) {
                                    await cancellationService.cancelJob(storeJob)
                                } else {
                                    workspaceStore.toast("Kuyruk güncellendi. Tekrar kontrol et.")
                                }
                                await workspaceStore.refreshGenerationQueue()
                            }
                        }
                    )
                    .disabled(isCancelling)
                    
                    if case .failed(let message) = cancelStatus {
                        Text(message)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.red)
                    } else if case .verifying = cancelStatus {
                        Text("İptal doğrulanıyor...")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadJobs() async {
        isLoading = true
        errorMessage = nil
        await workspaceStore.refresh()
        errorMessage = workspaceStore.errorMessage
        isLoading = false
    }

    private func pollActiveJobs() async {
        for _ in 0..<60 {
            guard jobs.contains(where: { $0.status == .pending || $0.status == .running }) else { return }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await workspaceStore.refreshGenerationQueue()
        }
    }

    private func queueStatus(from status: SBGenerationStatus) -> JobStatus {
        switch status {
        case .queued: return .pending
        case .running: return .running
        case .completed: return .completed
        case .failed: return .failed
        }
    }

    private func statusColor(_ status: JobStatus) -> Color {
        switch status {
        case .pending, .running: return SBColors.blue
        case .completed: return SBColors.green
        case .failed: return SBColors.red
        }
    }

    private func queueErrorMessage(_ message: String) -> String {
        let normalized = message.lowercased()
        if normalized.contains("cancelled") || normalized.contains("canceled") || normalized.contains("cancelledout") {
            return "Üretim yarıda kaldı. Tekrar deneyebilirsin."
        }
        if normalized.contains("timed out") || normalized.contains("timeout") {
            return "Üretim uzun sürdü. Tekrar deneyebilir veya sonra kontrol edebilirsin."
        }
        if normalized.contains("backend") || normalized.contains("edge function") || normalized.contains("server") {
            return "Şu anda hazırlanamadı. Biraz sonra tekrar dene."
        }
        return message
    }
}

#Preview {
    NavigationStack {
        QueueView(surface: .baseForce)
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}

extension SourceBaseQueueSurface {
    var title: String {
        switch self {
        case .all: return "Kuyruk"
        case .baseForce: return "Çalışma Kuyruğu"
        case .sourceLab: return "Derin Çalışma Kuyruğu"
        }
    }

    var eyebrow: String {
        switch self {
        case .all: return "Üretim takibi"
        case .baseForce: return "Kart, soru, özet"
        case .sourceLab: return "Klinik, plan, görsel"
        }
    }

    var message: String {
        switch self {
        case .all:
            return "Başlayan, hazırlanan ve hazır olan çalışmalar burada."
        case .baseForce:
            return "Kart, soru, son tekrar, akış ve tabloları buradan takip et."
        case .sourceLab:
            return "Klinik senaryo, plan, podcast ve görsel çalışmalarını buradan takip et."
        }
    }

    var emptyMessage: String {
        switch self {
        case .all:
            return "Üretim başlayınca burada görünür."
        case .baseForce:
            return "Kart, soru veya özet başlatınca burada takip edersin."
        case .sourceLab:
            return "Vaka, plan, podcast veya infografik başlatınca burada takip edersin."
        }
    }

    var icon: String {
        switch self {
        case .all: return "clock.badge.checkmark.fill"
        case .baseForce: return "bolt.fill"
        case .sourceLab: return "flask.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return SBColors.blue
        case .baseForce: return SBColors.blue
        case .sourceLab: return SBColors.purple
        }
    }

    func includes(_ kind: GeneratedKind) -> Bool {
        switch self {
        case .all:
            return true
        case .baseForce:
            switch kind {
            case .flashcard, .question, .summary, .algorithm, .comparison, .table:
                return true
            case .examMorningSummary, .clinicalScenario, .learningPlan, .podcast, .infographic, .mindMap:
                return false
            }
        case .sourceLab:
            switch kind {
            case .examMorningSummary, .clinicalScenario, .learningPlan, .podcast, .infographic, .mindMap:
                return true
            case .flashcard, .question, .summary, .algorithm, .comparison, .table:
                return false
            }
        }
    }

    static func surface(for kind: GeneratedKind) -> SourceBaseQueueSurface {
        if SourceBaseQueueSurface.sourceLab.includes(kind) {
            return .sourceLab
        }
        return .baseForce
    }
}
