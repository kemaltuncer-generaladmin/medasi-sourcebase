import SwiftUI
import SourceBaseBackend

struct UploadsView: View {
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var selectedFilter: UploadFilter = .all
    @State private var showDirectFileImporter = false

    private var uploads: [UploadTask] { workspaceStore.workspace.uploads }

    enum UploadFilter: String, CaseIterable {
        case all = "Tümü"
        case active = "İşleniyor"
        case completed = "Hazır"
        case failed = "Tekrar dene"

        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .active: return "arrow.triangle.2.circlepath"
            case .completed: return "checkmark.circle"
            case .failed: return "exclamationmark.triangle"
            }
        }

        var color: Color {
            switch self {
            case .all: return SBColors.blue
            case .active: return SBColors.blue
            case .completed: return SBColors.green
            case .failed: return SBColors.red
            }
        }
    }

    private var filteredUploads: [UploadTask] {
        switch selectedFilter {
        case .all: return uploads
        case .active: return uploads.filter { $0.status == .uploading || $0.status == .processing }
        case .completed: return uploads.filter { $0.status == .completed }
        case .failed: return uploads.filter { $0.status == .failed }
        }
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .all: return "Henüz yükleme yok"
        case .active: return "Devam eden yükleme yok"
        case .completed: return "Hazır dosya yok"
        case .failed: return "Tekrar denenecek kaynak yok"
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all: return "\(DriveUploadService.supportedExtensionsDisplay) dosyanı ekledikten sonra durum takibi burada görünür."
        case .active: return "Yeni dosya seçtiğinde yükleme ilerlemesi burada görünür."
        case .completed: return "Metni çıkarılıp üretime hazır olan dosyalar burada görünür."
        case .failed: return "Tamamlanmayan yüklemeleri buradan yeniden başlatabilirsin."
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SBSpacing.lg) {
                if workspaceStore.isLoading {
                    SBLoadingState(
                        icon: "icloud",
                        title: "Yüklemeler alınıyor",
                        message: "Dosya durumları hazırlanıyor..."
                    )
                } else if let error = workspaceStore.errorMessage {
                    SBErrorState(
                        title: "Yüklemeler alınamadı",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await workspaceStore.refresh() } }
                    )
                } else {
                    filterBar
                    uploadsList
                }
            }
            .padding(SBSpacing.lg)
            .sbReadableWidth(1180)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle("Hazır kaynaklar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showDirectFileImporter = true
                } label: {
                    Label("Yeni dosya", systemImage: "plus")
                }
            }
        }
        .driveDirectFileImporter(
            isPresented: $showDirectFileImporter,
            initialDestination: workspaceStore.preferredUploadDestination
        ) { _ in
            selectedFilter = .all
        }
        .task {
            await workspaceStore.loadWorkspace()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SBSpacing.sm) {
                ForEach(UploadFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: UploadFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: filter.icon)
                    .sbScaledFont(size: 14, weight: .semibold)

                Text(filter.rawValue)
                    .font(SBTypography.labelSmall)
            }
            .foregroundStyle(isSelected ? .white : filter.color)
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? filter.color : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? filter.color : filter.color.opacity(0.3), lineWidth: 1.5)
            )
        }
    }

    // MARK: - Uploads List

    @ViewBuilder
    private var uploadsList: some View {
        if uploads.isEmpty {
            SBEmptyState(
                icon: "icloud.and.arrow.up",
                title: emptyTitle,
                message: emptyMessage,
                badges: ["PDF", "PPTX", "DOCX", "PPT", "DOC"],
                actionLabel: "Yeni dosya",
                onAction: { showDirectFileImporter = true }
            )
        } else if filteredUploads.isEmpty {
            SBEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: emptyTitle,
                message: emptyMessage,
                badges: ["Durum takibi"],
                actionLabel: "Filtreyi temizle",
                onAction: { selectedFilter = .all }
            )
        } else {
            LazyVStack(spacing: SBSpacing.md) {
                ForEach(filteredUploads, id: \.file.id) { upload in
                    uploadCard(upload)
                }
            }
        }
    }

    // MARK: - Upload Card

    private func uploadCard(_ upload: UploadTask) -> some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    SBFileKindBadge(kind: SBFileKind.from(upload.file.kind), compact: false)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(upload.file.title)
                            .font(SBTypography.titleMedium)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)

                        Text("\(upload.file.sizeLabel) • \(upload.file.pageLabel)")
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)
                    }

                    Spacer()
                }

                FlowLayout(spacing: SBSpacing.xs) {
                    metaPill(icon: "folder", text: "\(upload.file.courseTitle) › \(upload.file.sectionTitle)")
                    metaPill(icon: "clock", text: upload.file.updatedLabel)
                }

                uploadStateView(upload)
            }
        }
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .sbScaledFont(size: 11)
                .foregroundStyle(SBColors.muted)
            Text(text)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(SBColors.field.opacity(0.82))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    // MARK: - Upload State View

    @ViewBuilder
    private func uploadStateView(_ upload: UploadTask) -> some View {
        switch upload.status {
        case .completed:
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                SBStatusBadge(status: .ready, compact: true)

                Text("Kaynak hazır. Üret ekranında kullanılabilir.")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
            }

        case .failed:
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                SBStatusBadge(status: .failed, compact: true)

                Text(upload.errorLabel ?? upload.file.statusMessage ?? "Kaynak hazırlanamadı.")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)

                SBButton(
                    "Tekrar dene",
                    icon: "arrow.clockwise",
                    variant: .secondary,
                    size: .small,
                    action: { retryUpload(upload) }
                )
            }

        case .processing:
            processingView(
                title: "Kaynak işleniyor",
                message: "Metin çıkarılıyor ve üretime hazırlanıyor.",
                progress: upload.progress,
                tags: [upload.file.sizeLabel, upload.file.pageLabel]
            )

        case .uploading:
            processingView(
                title: "Dosya yükleniyor",
                message: "Bu işlem dosya boyutuna göre kısa sürebilir.",
                progress: upload.progress,
                tags: [upload.file.sizeLabel]
            )

        case .draft:
            SBStatusBadge(status: .draft, compact: true)
        }
    }

    private func processingView(title: String, message: String, progress: Double, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            HStack(spacing: SBSpacing.sm) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: SBColors.blue))
                    .scaleEffect(0.8)

                Text(title)
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.blue)
            }

            Text(message)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)

            // Progress bar
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

            FlowLayout(spacing: SBSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SBColors.selectedBlue)
                        .clipShape(Capsule())
                }

                Text("İlerleme \(Int(progress * 100))%")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SBColors.selectedBlue)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Actions

    private func retryUpload(_ upload: UploadTask) {
        Task {
            await workspaceStore.retryFileProcessing(upload.file.id)
        }
    }

}

#Preview {
    NavigationStack {
        UploadsView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
