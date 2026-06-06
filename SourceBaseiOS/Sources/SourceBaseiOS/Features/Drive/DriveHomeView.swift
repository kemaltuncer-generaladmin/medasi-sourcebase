import SwiftUI
import SourceBaseBackend

struct DriveHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showUploadSheet = false
    @State private var showCreateCourse = false

    private var router: AppRouter { appState.router }
    private var workspace: DriveWorkspaceData { workspaceStore.workspace }

    private var allFiles: [DriveFile] {
        workspaceStore.allFiles
    }

    private var readyFiles: [DriveFile] {
        allFiles.filter { workspaceStore.isReadyForGeneration($0) }
    }

    private var readyCount: Int {
        readyFiles.count
    }

    private var processingCount: Int {
        allFiles.filter { $0.status == .processing || $0.status == .uploading }.count
    }

    private var recentReadyFiles: [DriveFile] {
        Array(readyFiles.prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if workspaceStore.isLoading {
                    SBLoadingState(
                        icon: "folder",
                        title: "Drive yükleniyor",
                        message: "Kaynakların hazırlanıyor..."
                    )
                } else if let error = workspaceStore.errorMessage {
                    SBErrorState(
                        title: "Drive yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar Dene",
                        onAction: { Task { await workspaceStore.refresh() } }
                    )
                } else {
                    headerSection.sbEntrance(0)
                    workspaceHero.sbEntrance(1)
                    if workspaceStore.uploadPhase != .idle {
                        SBNotice(
                            icon: workspaceStore.uploadPhase == .error ? "exclamationmark.triangle" : "icloud.and.arrow.up",
                            message: workspaceStore.uploadPhase.message,
                            tint: workspaceStore.uploadPhase == .error ? SBColors.red : SBColors.blue
                        )
                    }
                    primaryWorkspaceGrid.sbEntrance(2)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .frame(maxWidth: horizontalSizeClass == .regular ? 1260 : 1180, alignment: .center)
            .frame(maxWidth: .infinity)
        }
        .sbPageBackground()
        .sheet(isPresented: $showUploadSheet) {
            DriveUploadSheet(initialDestination: workspaceStore.preferredUploadDestination) { uploaded in
                if uploaded != nil {
                    router.navigate(to: .uploads)
                }
            }
        }
        .sheet(isPresented: $showCreateCourse) {
            SBCreateNodeSheet(
                heading: "Ders oluştur",
                placeholder: "Örn: Anatomi",
                confirmLabel: "Oluştur"
            ) { title, icon, color in
                Task { await workspaceStore.createCourse(title: title, iconName: icon, colorHex: color) }
            }
        }
        .refreshable {
            await workspaceStore.refresh()
        }
        .task {
            await workspaceStore.loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBPageHeader(
            title: "Drive",
            subtitle: "Ders notlarını sınava hazır kaynaklara dönüştür.",
            primaryIcon: "magnifyingglass",
            onPrimary: { router.navigate(to: .search) },
            onSecondary: nil
        )
    }

    private var workspaceHero: some View {
        SBSignatureHero(
            eyebrow: "Bugünkü çalışma",
            title: "Kaynak seç, üret, çalış",
            message: readyCount == 0 ? "\(DriveUploadService.supportedExtensionsDisplay) yükle; metin çıkınca kart, soru veya son tekrar çıkar." : "\(readyCount) kaynak hazır. Komite öncesi çalışmaya birinden başla.",
            icon: "folder.badge.gearshape",
            tint: SBColors.blue
        ) {
            HStack(spacing: SBSpacing.sm) {
                SBButton("Kaynak yükle", icon: "icloud.and.arrow.up", variant: .primary, size: .medium, fullWidth: true) {
                    showUploadSheet = true
                }
                if readyCount > 0 {
                    SBButton("Kaynak seç", icon: "checkmark.circle", variant: .secondary, size: .medium) {
                        router.switchTab(to: .baseForce)
                        router.navigate(to: .sourcePicker)
                    }
                }
            }
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "checkmark.seal", value: "\(readyCount)", label: "hazır", tint: SBColors.green),
                .init(icon: "clock", value: "\(processingCount)", label: "işlemde", tint: SBColors.orange),
                .init(icon: "rectangle.stack", value: "\(workspace.collections.count)", label: "koleksiyon", tint: SBColors.purple)
            ])
        }
    }

    // MARK: - Stats Row

    private var primaryWorkspaceGrid: some View {
        let minWidth: CGFloat = horizontalSizeClass == .regular ? 360 : 280
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: SBSpacing.lg)], alignment: .leading, spacing: SBSpacing.lg) {
            coursesSection
            readySourcesSection
            if !workspace.collections.isEmpty {
                collectionsSection
            }
        }
    }

    // MARK: - Ready Sources Section

    private var readySourcesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            sectionHeader(title: "Hazır kaynaklar", action: recentReadyFiles.isEmpty ? nil : "Kaynak seç") {
                router.switchTab(to: .baseForce)
                router.navigate(to: .sourcePicker)
            }

            if recentReadyFiles.isEmpty {
                SBEmptyState(
                    icon: processingCount > 0 ? "hourglass" : "folder.badge.plus",
                    title: processingCount > 0 ? "Kaynak işleniyor" : "Henüz hazır kaynak yok",
                    message: processingCount > 0 ? "Metin çıkınca burada seçip çalışma seti hazırlayabilirsin." : "Bir ders notu yükle. Hazır olunca buradan çalışmaya geç.",
                    badges: ["PDF", "PPTX", "DOCX"],
                    actionLabel: processingCount > 0 ? "Yüklemeler" : "Kaynak yükle",
                    onAction: {
                        if processingCount > 0 {
                            router.navigate(to: .uploads)
                        } else {
                            showUploadSheet = true
                        }
                    }
                )
            } else {
                VStack(spacing: SBSpacing.md) {
                    ForEach(recentReadyFiles) { file in
                        readySourceCard(file: file)
                    }
                }
            }
        }
    }

    // MARK: - Courses Section

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            sectionHeader(
                title: "Derslerim",
                action: "Ders ekle"
            ) {
                showCreateCourse = true
            }

            if workspace.courses.isEmpty {
                SBEmptyState(
                    icon: "plus.rectangle.on.folder",
                    title: "Ders yok",
                    message: "Ders oluştur, kaynakları içine at.",
                    badges: ["Ders", "Bölüm", "Kaynak"],
                    actionLabel: "Ders oluştur",
                    onAction: { showCreateCourse = true }
                )
            } else {
                SBCard {
                    VStack(spacing: SBSpacing.md) {
                        // Course list — her ders kendi dosya sayısını gösterir
                        ForEach(Array(workspace.courses.prefix(3)), id: \.id) { course in
                            Button {
                                router.navigate(to: .courseDetail(courseId: course.id))
                            } label: {
                                courseRow(course: course)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(course.title)
                            .accessibilityValue("\(course.sections.count) bölüm, \(course.fileCount) dosya, \(course.status == .draft ? "beklemede" : "aktif")")
                            .accessibilityHint("Ders detayını açar")
                            .accessibilityAddTraits(.isButton)

                            if course.id != workspace.courses.prefix(3).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func courseRow(course: DriveCourse) -> some View {
        HStack(spacing: SBSpacing.md) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: course.iconColorHex).opacity(0.14))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: course.iconName)
                        .sbScaledFont(size: 22)
                        .foregroundStyle(Color(hex: course.iconColorHex))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SBSpacing.xs) {
                Text(course.title)
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)

                Text("\(course.sections.count) bölüm • \(course.fileCount) dosya")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
            }

            Spacer()

            Text(course.status == .draft ? "Beklemede" : "Aktif")
                .font(SBTypography.caption)
                .foregroundStyle(course.status == .draft ? SBColors.blue : SBColors.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(course.status == .draft ? SBColors.selectedBlue : SBColors.greenBg)
                .clipShape(Capsule())
        }
        .padding(.vertical, SBSpacing.xs)
    }

    private func readySourceCard(file: DriveFile) -> some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    SBFileKindBadge(kind: SBFileKind.from(file.kind))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(file.title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        FlowLayout(spacing: SBSpacing.sm) {
                            SBStatusBadge(status: SBStatus.from(file.status), compact: true)
                            Text(file.courseTitle)
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.muted)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(SBColors.field.opacity(0.82))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SBSpacing.sm) {
                        SBButton("İncele", icon: "doc.text.magnifyingglass", variant: .secondary, size: .small, fullWidth: true) {
                            router.navigate(to: .fileDetail(fileId: file.id))
                        }
                        SBButton("Seç ve üret", icon: "bolt.fill", variant: .primary, size: .small, fullWidth: true) {
                            selectSourceAndOpenBaseForce(file)
                        }
                    }

                    VStack(spacing: SBSpacing.sm) {
                        SBButton("Seç ve üret", icon: "bolt.fill", variant: .primary, size: .small, fullWidth: true) {
                            selectSourceAndOpenBaseForce(file)
                        }
                        SBButton("İncele", icon: "doc.text.magnifyingglass", variant: .secondary, size: .small, fullWidth: true) {
                            router.navigate(to: .fileDetail(fileId: file.id))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Collections Section

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            sectionHeader(title: "Son koleksiyonlar", action: workspace.collections.isEmpty ? nil : "Koleksiyonlar") {
                router.navigate(to: .collections)
            }

            if workspace.collections.isEmpty {
                SBEmptyState(
                    icon: "rectangle.stack",
                    title: "Çalışma çıktısı yok",
                    message: "Kart, soru veya özet üretince burada çalışırsın.",
                    badges: ["Flashcard", "Soru", "Özet"],
                    actionLabel: "Koleksiyonlar",
                    onAction: { router.navigate(to: .collections) }
                )
            } else {
                VStack(spacing: SBSpacing.md) {
                    ForEach(Array(workspace.collections.prefix(3)), id: \.file.id) { bundle in
                        collectionCard(bundle: bundle)
                    }
                }
            }
        }
    }

    private func collectionCard(bundle: CollectionBundle) -> some View {
        SBCard(radius: 14) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SBColors.blue.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: "bolt.fill")
                            .sbScaledFont(size: 18)
                            .foregroundStyle(SBColors.blue)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(bundle.outputs.first?.title ?? "Koleksiyon")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(1)

                        Text(bundle.file.title)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    SBStatusBadge(status: .ready, compact: true)
                }

                if let output = bundle.outputs.first {
                    Text(output.detail)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(3)
                }

                HStack {
                    Text(bundle.file.updatedLabel)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.softText)

                    Spacer()

                    Button("Çalış") {
                        if let output = bundle.outputs.first {
                            router.navigate(to: .studyOutput(outputId: output.id))
                        } else {
                            router.navigate(to: .collections)
                        }
                    }
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.blue)
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

    private func selectSourceAndOpenBaseForce(_ file: DriveFile) {
        workspaceStore.setSelectedSources([file.id])
        workspaceStore.selectFile(file)
        workspaceStore.toast("Kaynak seçildi. Üretim türünü seç.")
        router.switchTab(to: .baseForce)
        router.navigate(to: .sourcePicker)
    }

}

#Preview {
    DriveHomeView()
        .environment(AppState.shared)
}
