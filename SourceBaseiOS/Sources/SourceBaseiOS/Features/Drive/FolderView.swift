import SwiftUI
import SourceBaseBackend

struct FolderView: View {
    let courseId: String
    let sectionId: String

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var section: DriveSection?
    @State private var courseTitle: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFileIds: Set<String> = []
    @State private var kindFilter: SBFileKind?
    @State private var sortOrder: SortOrder = .newest
    @State private var showUploadSheet = false
    @State private var filePendingDelete: DriveFile?
    @State private var showBulkDeleteConfirmation = false
    @State private var fileIdsPendingMove: Set<String> = []
    @State private var showMoveSheet = false

    private var router: AppRouter { appState.router }

    private enum SortOrder: String, CaseIterable {
        case newest = "En yeni"
        case name = "Ada göre"
        case kind = "Türe göre"
    }

    private var visibleFiles: [DriveFile] {
        guard let files = section?.files else { return [] }
        let filtered = kindFilter == nil ? files : files.filter { SBFileKind.from($0.kind) == kindFilter }

        switch sortOrder {
        case .newest: return filtered
        case .name: return filtered.sorted { $0.title < $1.title }
        case .kind: return filtered.sorted { $0.kind.rawValue < $1.kind.rawValue }
        }
    }

    private var hasSelection: Bool { !selectedFileIds.isEmpty }

    private var initialUploadDestination: DriveDestination? {
        guard let section else { return workspaceStore.preferredUploadDestination }
        return DriveDestination(courseId: courseId, sectionId: sectionId, courseTitle: courseTitle, sectionTitle: section.title)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "folder",
                        title: "Bölüm yükleniyor",
                        message: "Dosyalar hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Bölüm yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadSection() } }
                    )
                } else if section == nil {
                    SBErrorState(
                        icon: "folder.badge.questionmark",
                        title: "Bölüm bulunamadı",
                        message: "Bu bölüm silinmiş veya Drive verisi yenilenmiş olabilir.",
                        actionLabel: "Drive'a dön",
                        onAction: { router.popToRoot() }
                    )
                } else {
                    headerSection
                    actionButtons
                    toolbarSection
                    filesList
                    if hasSelection {
                        selectionTray
                    }
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle(section?.title ?? "Bölüm")
        .sheet(isPresented: $showUploadSheet) {
            DriveUploadSheet(initialDestination: initialUploadDestination) { _ in
                Task { await loadSection() }
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            DriveMoveSheet(
                fileCount: fileIdsPendingMove.count,
                currentSectionId: sectionId
            ) { destination in
                Task {
                    await workspaceStore.moveFiles(
                        Array(fileIdsPendingMove),
                        courseId: destination.courseId,
                        sectionId: destination.sectionId
                    )
                    fileIdsPendingMove.removeAll()
                    selectedFileIds.removeAll()
                    await loadSection()
                }
            }
        }
        .alert("Dosya silinsin mi?", isPresented: .constant(filePendingDelete != nil), presenting: filePendingDelete) { file in
            Button("Sil", role: .destructive) {
                Task {
                    await workspaceStore.deleteFiles([file.id])
                    filePendingDelete = nil
                    await loadSection()
                }
            }
            Button("Vazgeç", role: .cancel) {
                filePendingDelete = nil
            }
        } message: { file in
            Text("\(file.title) Drive alanından kaldırılacak.")
        }
        .alert("Seçili dosyalar silinsin mi?", isPresented: $showBulkDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                Task {
                    await workspaceStore.deleteFiles(Array(selectedFileIds))
                    selectedFileIds.removeAll()
                    await loadSection()
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("\(selectedFileIds.count) dosya Drive alanından kaldırılacak.")
        }
        .task {
            await loadSection()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.xs) {
            if !courseTitle.isEmpty {
                Text("\(courseTitle) • \(visibleFiles.count) dosya")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: SBSpacing.md) {
            SBButton(
                "Dosya yükle",
                icon: "plus",
                variant: .primary,
                size: .small,
                fullWidth: true,
                action: { showUploadSheet = true }
            )

            SBButton(
                hasSelection ? "Seçimi Kaldır" : "Tümünü Seç",
                icon: hasSelection ? "xmark.circle" : "checkmark.circle",
                variant: .secondary,
                size: .small,
                fullWidth: true,
                action: toggleSelectAll
            )
        }
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        SBCard(padding: SBSpacing.md, radius: 12) {
            HStack(spacing: SBSpacing.lg) {
                // Filter
                Menu {
                    Button("Tümü") { kindFilter = nil }
                    Button("PDF") { kindFilter = .pdf }
                    Button("PPTX") { kindFilter = .pptx }
                    Button("DOCX") { kindFilter = .docx }
                    Button("PPT") { kindFilter = .ppt }
                    Button("DOC") { kindFilter = .doc }
                } label: {
                    HStack(spacing: SBSpacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .sbScaledFont(size: 16)
                        Text(kindFilter?.label ?? "Filtrele")
                            .font(SBTypography.labelSmall)
                    }
                    .foregroundStyle(SBColors.navy)
                }

                Divider().frame(height: 20)

                // Sort
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) { sortOrder = order }
                    }
                } label: {
                    HStack(spacing: SBSpacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                            .sbScaledFont(size: 16)
                        Text(sortOrder.rawValue)
                            .font(SBTypography.labelSmall)
                        Image(systemName: "chevron.down")
                            .sbScaledFont(size: 10)
                    }
                    .foregroundStyle(SBColors.navy)
                }

                Spacer()
            }
        }
    }

    // MARK: - Files List

    @ViewBuilder
    private var filesList: some View {
        if section?.files.isEmpty == true {
            SBEmptyState(
                icon: "doc.badge.plus",
                title: "Bu bölümde henüz dosya yok",
                message: "Yeni dosyalar yükleyerek başlayabilirsin.",
                actionLabel: "Dosya yükle",
                onAction: { showUploadSheet = true }
            )
        } else if visibleFiles.isEmpty {
            SBEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: "Bu filtrede dosya yok",
                message: "Dosya türü filtresini temizleyerek tekrar deneyebilirsin."
            )
        } else {
            LazyVStack(spacing: SBSpacing.md) {
                ForEach(visibleFiles) { file in
                    fileRow(file: file)
                }
            }
        }
    }

    private func fileRow(file: DriveFile) -> some View {
        let isSelected = selectedFileIds.contains(file.id)

        return SBCard(radius: 14, borderColor: isSelected ? SBColors.blue.opacity(0.4) : SBColors.softLine) {
            HStack(spacing: SBSpacing.md) {
                Button {
                    toggleSelection(file.id)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? SBColors.blue : SBColors.white)
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isSelected ? SBColors.blue : SBColors.line, lineWidth: 1.5)
                            )

                        if isSelected {
                            Image(systemName: "checkmark")
                                .sbScaledFont(size: 14, weight: .bold)
                            .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Seçimi kaldır" : "Dosyayı seç")
                .accessibilityValue(file.title)

                SBFileKindBadge(kind: SBFileKind.from(file.kind))

                Button {
                    router.navigate(to: .fileDetail(fileId: file.id))
                } label: {
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(file.title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        FlowLayout(spacing: SBSpacing.sm) {
                            Text(SBFileKind.from(file.kind).label)
                                .font(SBTypography.caption)
                                .foregroundStyle(SBFileKind.from(file.kind).color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SBFileKind.from(file.kind).color.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text(file.pageLabel)
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.muted)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(file.title) dosyasını aç")
                .accessibilityValue("\(SBFileKind.from(file.kind).label), \(file.pageLabel)")
                .accessibilityHint("Dosya detayını açar")

                Spacer()

                VStack(alignment: .trailing, spacing: SBSpacing.xs) {
                    Text(file.sizeLabel)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    Text(file.updatedLabel)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }

                fileMenu(file)
            }
        }
        .contextMenu {
            Button("Aç", systemImage: "arrow.up.right.square") {
                router.navigate(to: .fileDetail(fileId: file.id))
            }
            Button("Üretim için seç", systemImage: "checkmark.circle") {
                workspaceStore.toggleSource(file)
            }
            Button("Taşı", systemImage: "folder.badge.gearshape") {
                fileIdsPendingMove = [file.id]
                showMoveSheet = true
            }
            if file.status == .failed {
                Button("İşlemeyi tekrar dene", systemImage: "arrow.clockwise") {
                    Task { await workspaceStore.retryFileProcessing(file.id) }
                }
            }
            Button("Sil", systemImage: "trash", role: .destructive) {
                filePendingDelete = file
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func fileMenu(_ file: DriveFile) -> some View {
        Menu {
            Button("Aç", systemImage: "arrow.up.right.square") {
                router.navigate(to: .fileDetail(fileId: file.id))
            }
            Button("Üretim için seç", systemImage: "checkmark.circle") {
                workspaceStore.toggleSource(file)
            }
            Button("Taşı", systemImage: "folder.badge.gearshape") {
                fileIdsPendingMove = [file.id]
                showMoveSheet = true
            }
            if file.status == .failed {
                Button("İşlemeyi tekrar dene", systemImage: "arrow.clockwise") {
                    Task { await workspaceStore.retryFileProcessing(file.id) }
                }
            }
            Button("Sil", systemImage: "trash", role: .destructive) {
                filePendingDelete = file
            }
        } label: {
            Image(systemName: "ellipsis")
                .sbScaledFont(size: 17, weight: .semibold)
                .foregroundStyle(SBColors.muted)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Dosya işlemleri")
    }

    // MARK: - Selection Tray

    private var selectionTray: some View {
        SBCard(radius: 14, borderColor: SBColors.blue.opacity(0.3)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                Text("\(selectedFileIds.count) öğe seçildi")
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)

                Text("Seçili kaynaklardan hızlıca öğrenme çıktısı üretin.")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    trayAction(icon: "doc.text", label: "Özet", color: SBColors.purple) {
                        generateSelected(.summary)
                    }
                    trayAction(icon: "rectangle.on.rectangle", label: "Flashcard", color: SBColors.green) {
                        generateSelected(.flashcard)
                    }
                    trayAction(icon: "rectangle.stack", label: "Koleksiyonlar", color: SBColors.navy) {
                        router.navigate(to: .collections)
                    }
                    trayAction(icon: "folder.badge.gearshape", label: "Taşı", color: SBColors.blue) {
                        fileIdsPendingMove = selectedFileIds
                        showMoveSheet = true
                    }
                    trayAction(icon: "trash", label: "Sil", color: SBColors.red) {
                        showBulkDeleteConfirmation = true
                    }
                    trayAction(icon: "xmark", label: "Temizle", color: SBColors.muted) {
                        selectedFileIds.removeAll()
                    }
                }
            }
        }
    }

    private func trayAction(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 22)
                    .foregroundStyle(color)

                Text(label)
                    .font(SBTypography.caption)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleSelection(_ fileId: String) {
        if selectedFileIds.contains(fileId) {
            selectedFileIds.remove(fileId)
        } else {
            selectedFileIds.insert(fileId)
        }
    }

    private func toggleSelectAll() {
        if hasSelection {
            selectedFileIds.removeAll()
        } else {
            selectedFileIds = Set(visibleFiles.map { $0.id })
        }
    }

    private func generateSelected(_ kind: GeneratedKind) {
        let selectedFiles = visibleFiles.filter { file in
            selectedFileIds.contains(file.id) && workspaceStore.isReadyForGeneration(file)
        }
        guard let first = selectedFiles.first else {
            workspaceStore.toast("Üretim için hazır bir dosya seç.")
            return
        }

        workspaceStore.setSelectedSources(Set(selectedFiles.map(\.id)))
        Task {
            _ = await workspaceStore.enqueueDriveGeneration(
                file: first,
                kind: kind,
                sourceIds: Set(selectedFiles.map(\.id))
            )
            router.navigate(to: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
            selectedFileIds.removeAll()
        }
    }

    private func loadSection() async {
        isLoading = true
        errorMessage = nil

        await workspaceStore.loadWorkspace()
        if let course = workspaceStore.workspace.courses.first(where: { $0.id == courseId }) {
            courseTitle = course.title
            section = course.sections.first(where: { $0.id == sectionId })
        } else {
            section = nil
            courseTitle = ""
        }
        errorMessage = workspaceStore.errorMessage

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FolderView(courseId: "course-1", sectionId: "section-1")
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
