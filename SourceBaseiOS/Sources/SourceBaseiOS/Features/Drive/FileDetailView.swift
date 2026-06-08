import SwiftUI
import SourceBaseBackend

struct FileDetailView: View {
    let fileId: String

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var showRenameAlert = false
    @State private var renameTitle = ""
    @State private var showDeleteConfirmation = false
    @State private var showMoveSheet = false
    @State private var isRetrying = false

    private var router: AppRouter { appState.router }
    private var file: DriveFile? { workspaceStore.file(id: fileId) }

    private var isReadyForGeneration: Bool {
        guard let file else { return false }
        return workspaceStore.isReadyForGeneration(file)
    }

    private var readinessMessage: String {
        guard let file else { return "" }
        if let msg = file.statusMessage, !msg.isEmpty {
            return msg
        }
        switch file.status {
        case .completed: return "Kaynak üretime hazır."
        case .processing: return "Kaynak hazırlanıyor. Hazır olunca üretim başlatabilirsin."
        case .uploading: return "Yükleme devam ediyor."
        case .failed: return "Dosya işlenemedi. Farklı bir dosya deneyebilirsin."
        case .draft: return "Kaynak henüz hazır değil."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if workspaceStore.isLoading {
                    SBLoadingState(
                        icon: "doc",
                        title: "Dosya yükleniyor",
                        message: "Dosya bilgileri hazırlanıyor..."
                    )
                } else if let error = workspaceStore.errorMessage {
                    SBErrorState(
                        title: "Dosya yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await workspaceStore.refresh() } }
                    )
                } else if let file {
                    fileInfoCard(file).sbEntrance(0)
                    locationRow(file).sbEntrance(1)

                    if !isReadyForGeneration {
                        readinessNotice.sbEntrance(2)
                    }

                    studyActionsSection.sbEntrance(3)
                    generatedOutputsSection.sbEntrance(4)
                } else {
                    SBErrorState(
                        icon: "doc.questionmark",
                        title: "Dosya bulunamadı",
                        message: "Bu kaynak silinmiş veya Drive verisi yenilenmiş olabilir.",
                        actionLabel: "Drive'a dön",
                        onAction: { router.popToRoot() }
                    )
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle("Dosya Detayı")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                fileActionsMenu
            }
        }
        .alert("Dosyayı yeniden adlandır", isPresented: $showRenameAlert) {
            TextField("Dosya adı", text: $renameTitle)
            Button("Kaydet") {
                guard let file else { return }
                Task { await workspaceStore.renameFile(file.id, title: renameTitle) }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Drive içinde görünen kaynak adını günceller.")
        }
        .alert("Dosya silinsin mi?", isPresented: $showDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                guard let file else { return }
                Task {
                    await workspaceStore.deleteFiles([file.id])
                    router.popToRoot()
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(file.map { "\($0.title) Drive alanından kaldırılacak." } ?? "Dosya kaldırılacak.")
        }
        .sheet(isPresented: $showMoveSheet) {
            DriveMoveSheet(
                fileCount: 1,
                currentSectionId: currentSectionId
            ) { destination in
                guard let file else { return }
                Task {
                    await workspaceStore.moveFiles(
                        [file.id],
                        courseId: destination.courseId,
                        sectionId: destination.sectionId
                    )
                    await workspaceStore.refresh()
                }
            }
        }
        .task {
            await loadFile()
        }
    }

    private var currentSectionId: String? {
        workspaceStore.workspace.courses
            .flatMap(\.sections)
            .first { section in
                section.files.contains { $0.id == fileId }
            }?
            .id
    }

    @ViewBuilder
    private var fileActionsMenu: some View {
        if let file {
            Menu {
                Button("Yeniden adlandır", systemImage: "pencil") {
                    renameTitle = file.title
                    showRenameAlert = true
                }
                Button("Taşı", systemImage: "folder.badge.gearshape") {
                    showMoveSheet = true
                }
                if file.status == .failed || file.status == .processing {
                    Button("İşlemeyi tekrar dene", systemImage: "arrow.clockwise") {
                        Task { await workspaceStore.retryFileProcessing(file.id) }
                    }
                }
                Button("Sil", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Dosya işlemleri")
        }
    }

    // MARK: - File Info Card

    private func fileInfoCard(_ file: DriveFile) -> some View {
        SBSignatureHero(
            eyebrow: SBFileKind.from(file.kind).label,
            title: file.title,
            message: readinessMessage,
            icon: "doc.text.fill",
            tint: SBFileKind.from(file.kind).color
        ) {
            FlowLayout(spacing: SBSpacing.sm) {
                SBStatusBadge(status: SBStatus.from(file.status), compact: true)
                metaItem(icon: "folder", text: file.courseTitle)
                metaItem(icon: "list.bullet", text: file.sectionTitle)
            }
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "doc", value: file.sizeLabel, label: "boyut", tint: SBFileKind.from(file.kind).color),
                .init(icon: "number", value: file.pageLabel, label: "sayfa", tint: SBColors.blue),
                .init(icon: "calendar", value: file.updatedLabel, label: "güncelleme", tint: SBColors.green)
            ])
        }
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .sbScaledFont(size: 12)
                .foregroundStyle(SBColors.muted)
            Text(text)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)
        }
    }

    // MARK: - Location Row

    private func locationRow(_ file: DriveFile) -> some View {
        SBCard(padding: SBSpacing.md, radius: 12) {
            FlowLayout(spacing: SBSpacing.md) {
                Image(systemName: "folder")
                    .sbScaledFont(size: 16)
                    .foregroundStyle(SBColors.muted)

                Text(file.courseTitle)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 12)
                    .foregroundStyle(SBColors.navy)

                Text(file.sectionTitle)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.blue)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Readiness Notice

    private var readinessNotice: some View {
        SBCard(padding: SBSpacing.md, radius: 12, backgroundColor: SBColors.selectedBlue) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    Image(systemName: "info.circle")
                        .sbScaledFont(size: 18)
                        .foregroundStyle(SBColors.blue)

                    Text(canRetryProcessing && file?.status == .processing
                         ? "\(readinessMessage) Uzun sürdüyse işlemeyi yeniden başlatabilirsin."
                         : readinessMessage)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.muted)
                        .lineSpacing(2)
                }

                if canRetryProcessing {
                    SBButton(
                        isRetrying ? "Yeniden başlatılıyor..." : "İşlemeyi yeniden başlat",
                        icon: "arrow.clockwise",
                        variant: .secondary,
                        size: .small,
                        isLoading: isRetrying
                    ) {
                        retryProcessing()
                    }
                }
            }
        }
    }

    private var canRetryProcessing: Bool {
        guard let file else { return false }
        return file.status == .failed || file.status == .processing
    }

    private func retryProcessing() {
        guard let file, !isRetrying else { return }
        isRetrying = true
        Task {
            await workspaceStore.retryFileProcessing(file.id)
            isRetrying = false
        }
    }

    // MARK: - Study Actions

    private var studyActionsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Bu kaynakla çalış")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            if isReadyForGeneration {
                studyActionsPanel
            } else {
                SBEmptyState(
                    icon: file?.status == .failed ? "exclamationmark.triangle" : "hourglass",
                    title: file?.status == .failed ? "Kaynak işlenemedi" : "Dosya hazır değil",
                    message: readinessMessage
                )
            }
        }
    }

    private var studyActionsPanel: some View {
        SBCard(radius: 14) {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                // Route cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: SBSpacing.md)], spacing: SBSpacing.md) {
                    routeCard(
                        icon: "bolt.fill",
                        title: "Hızlı çalışma",
                        subtitle: "Ezber kartı, test ve son tekrar",
                        color: SBColors.blue
                    ) {
                        if let file {
                            workspaceStore.setSelectedSources([file.id])
                            workspaceStore.selectFile(file)
                        }
                        router.beginSourceSelection(from: .baseForce, destination: .baseForceHome)
                    }

                    routeCard(
                        icon: "flask",
                        title: "Üretim araçları",
                        subtitle: "Vaka, plan, dinleme ve görsel özet",
                        color: SBColors.purple
                    ) {
                        if let file {
                            workspaceStore.setSelectedSources([file.id])
                            workspaceStore.selectFile(file)
                        }
                        router.beginSourceSelection(from: .sourceLab, destination: .sourceLabHome)
                    }
                }

                // Quick generate chips
                FlowLayout(spacing: SBSpacing.sm) {
                    quickChip(icon: "rectangle.on.rectangle", label: "Kart", accessibilityLabel: "Bu dosyadan flashcard üret", color: SBColors.blue) {
                        Task { await generate(.flashcard) }
                    }
                    quickChip(icon: "questionmark.circle", label: "Soru", accessibilityLabel: "Bu dosyadan soru seti üret", color: SBColors.questionTint) {
                        Task { await generate(.question) }
                    }
                    quickChip(icon: "doc.text", label: "Özet", accessibilityLabel: "Bu dosyadan özet üret", color: SBColors.purple) {
                        Task { await generate(.summary) }
                    }
                }
            }
        }
    }

    private func routeCard(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        SBCommandCard(tint: color, action: action) {
            HStack(spacing: SBSpacing.md) {
                SBIconTile(icon: icon, tint: color, size: 40, radius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.navy)

                    Text(subtitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 14)
                    .foregroundStyle(color)
            }
        }
    }

    private func quickChip(icon: String, label: String, accessibilityLabel: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 14)
                    .foregroundStyle(color)

                Text(label)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SBColors.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Üretimi bu dosyayla başlatır")
    }

    // MARK: - Generated Outputs

    private var generatedOutputsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            HStack {
                Text("Bu kaynaktan üretilenler")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)

                Spacer()

                if let file, !file.generated.isEmpty {
                    Button("Tümünü gör") {
                        router.navigate(to: .collections)
                    }
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.blue)
                }
            }

            SBCard(padding: 0, radius: 14) {
                if let file, file.generated.isEmpty {
                    VStack(spacing: SBSpacing.md) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .sbScaledFont(size: 28)
                            .foregroundStyle(SBColors.muted.opacity(0.5))

                        Text("Henüz çalışma yok")
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)

                        Text(isReadyForGeneration
                             ? "Yukarıdaki seçeneklerden biriyle çalışma başlatabilirsin."
                             : "Kaynak hazır olunca çalışmalar burada görünür.")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.softText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(SBSpacing.xl)
                    .frame(maxWidth: .infinity)
                } else if let file {
                    VStack(spacing: 0) {
                        ForEach(Array(file.generated.enumerated()), id: \.element.id) { index, output in
                            Button {
                                router.navigate(to: .studyOutput(outputId: output.id))
                            } label: {
                                generatedRow(output: output)
                            }
                            .buttonStyle(.plain)

                            if index < file.generated.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func generatedRow(output: GeneratedOutput) -> some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: SBOutputStyle.outputIcon(output.kind))
                .sbScaledFont(size: 22)
                .foregroundStyle(SBOutputStyle.outputColor(output.kind))

            VStack(alignment: .leading, spacing: SBSpacing.xs) {
                Text(output.title)
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)

                Text(output.detail)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(output.updatedLabel)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.muted)

            Image(systemName: "chevron.right")
                .sbScaledFont(size: 14)
                .foregroundStyle(SBColors.softText)
        }
        .padding(SBSpacing.md)
    }

    // MARK: - Loading

    private func loadFile() async {
        await workspaceStore.loadWorkspace()
    }

    private func generate(_ kind: GeneratedKind) async {
        guard let file else { return }
        _ = await workspaceStore.enqueueDriveGeneration(file: file, kind: kind)
        router.navigate(to: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
    }
}

#Preview {
    NavigationStack {
        FileDetailView(fileId: "test-file")
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
