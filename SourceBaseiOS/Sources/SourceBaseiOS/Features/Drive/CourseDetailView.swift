import SwiftUI
import SourceBaseBackend

struct CourseDetailView: View {
    let courseId: String

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var selectedTab: Tab = .sections
    @State private var showDirectFileImporter = false
    @State private var showRenameAlert = false
    @State private var renameTitle = ""
    @State private var showDeleteConfirmation = false
    @State private var sectionPendingRename: DriveSection?
    @State private var sectionPendingDelete: DriveSection?
    @State private var sectionRenameTitle = ""
    @State private var showCreateSection = false

    private var router: AppRouter { appState.router }
    private var course: DriveCourse? { workspaceStore.course(id: courseId) }

    private enum Tab: String, CaseIterable {
        case sections = "Bölümler"
        case files = "Dosyalar"
        case details = "Ayrıntılar"
    }

    private var allFiles: [DriveFile] {
        course?.sections.flatMap { $0.files } ?? []
    }

    private var initialUploadDestination: DriveDestination? {
        guard let course, let section = course.sections.first else { return workspaceStore.preferredUploadDestination }
        return DriveDestination(courseId: course.id, sectionId: section.id, courseTitle: course.title, sectionTitle: section.title)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SBSpacing.lg) {
                if workspaceStore.isLoading && !workspaceStore.hasLoadedWorkspace {
                    SBLoadingState(
                        icon: "book",
                        title: "Ders yükleniyor",
                        message: "Bölümler ve dosyalar hazırlanıyor..."
                    )
                } else if let error = workspaceStore.errorMessage {
                    SBErrorState(
                        title: "Ders yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await workspaceStore.refresh() } }
                    )
                } else if let course {
                    courseHeader(course).sbEntrance(0)
                    tabSelector.sbEntrance(1)
                    tabContent.sbEntrance(2)
                } else {
                    SBErrorState(
                        icon: "book.closed",
                        title: "Ders bulunamadı",
                        message: "Bu ders silinmiş veya Drive verisi yenilenmiş olabilir.",
                        actionLabel: "Drive'a dön",
                        onAction: { router.popToRoot() }
                    )
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle(course?.title ?? "Ders")
        .sbInlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                courseActionsMenu
            }
        }
        .alert("Dersi yeniden adlandır", isPresented: $showRenameAlert) {
            TextField("Ders adı", text: $renameTitle)
            Button("Kaydet") {
                Task { await workspaceStore.renameCourse(courseId, title: renameTitle) }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Ders adı Drive boyunca güncellenir.")
        }
        .alert("Ders silinsin mi?", isPresented: $showDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                Task {
                    await workspaceStore.deleteCourse(courseId)
                    router.popToRoot()
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(course.map { "\($0.title) içindeki bölüm ve dosyalar kaldırılacak." } ?? "Ders kaldırılacak.")
        }
        .alert("Bölümü yeniden adlandır", isPresented: .constant(sectionPendingRename != nil), presenting: sectionPendingRename) { section in
            TextField("Bölüm adı", text: $sectionRenameTitle)
            Button("Kaydet") {
                Task {
                    await workspaceStore.renameSection(section.id, title: sectionRenameTitle)
                    sectionPendingRename = nil
                }
            }
            Button("Vazgeç", role: .cancel) {
                sectionPendingRename = nil
            }
        } message: { _ in
            Text("Bölüm adı Drive boyunca güncellenir.")
        }
        .alert("Bölüm silinsin mi?", isPresented: .constant(sectionPendingDelete != nil), presenting: sectionPendingDelete) { section in
            Button("Sil", role: .destructive) {
                Task {
                    await workspaceStore.deleteSection(section.id)
                    sectionPendingDelete = nil
                }
            }
            Button("Vazgeç", role: .cancel) {
                sectionPendingDelete = nil
            }
        } message: { section in
            Text("\(section.title) içindeki dosyalar kaldırılacak.")
        }
        .driveDirectFileImporter(
            isPresented: $showDirectFileImporter,
            initialDestination: initialUploadDestination
        ) { _ in
            Task { await loadCourse() }
            selectedTab = .files
        }
        .sheet(isPresented: $showCreateSection) {
            SBCreateNodeSheet(
                heading: "Bölüm oluştur",
                placeholder: "Örn: Üst Ekstremite",
                confirmLabel: "Oluştur"
            ) { title, icon, color in
                Task {
                    if let section = await workspaceStore.createSection(courseId: courseId, title: title, iconName: icon, colorHex: color) {
                        router.navigate(to: .folder(courseId: courseId, sectionId: section.id))
                    } else {
                        await loadCourse()
                    }
                }
            }
        }
        .task {
            await loadCourse()
        }
    }

    @ViewBuilder
    private var courseActionsMenu: some View {
        if let course {
            Menu {
                Button("Yeniden adlandır", systemImage: "pencil") {
                    renameTitle = course.title
                    showRenameAlert = true
                }
                Button("Sil", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Ders işlemleri")
        }
    }

    // MARK: - Course Header

    private func courseHeader(_ course: DriveCourse) -> some View {
        SBSignatureHero(
            eyebrow: "Ders alanı",
            title: course.title,
            message: course.description,
            icon: course.iconName,
            tint: Color(hex: course.iconColorHex)
        ) {
            HStack(spacing: SBSpacing.sm) {
                SBButton("Dosya yükle", icon: "icloud.and.arrow.up", variant: .primary, size: .small) {
                    showDirectFileImporter = true
                }
                SBButton("Bölüm ekle", icon: "folder.badge.plus", variant: .secondary, size: .small) {
                    showCreateSection = true
                }
            }
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "folder", value: "\(course.sections.count)", label: "bölüm", tint: Color(hex: course.iconColorHex)),
                .init(icon: "doc", value: "\(course.fileCount)", label: "dosya", tint: SBColors.blue),
                .init(icon: "clock", value: course.updatedLabel, label: "güncelleme", tint: SBColors.green)
            ])
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        SBCard(padding: 4, radius: 12) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tabIcon(tab))
                                .sbScaledFont(size: 16)
                            Text(tab.rawValue)
                                .font(SBTypography.labelSmall)
                        }
                        .foregroundStyle(selectedTab == tab ? .white : SBColors.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SBSpacing.sm)
                        .background(
                            selectedTab == tab ? SBColors.blue : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tabIcon(_ tab: Tab) -> String {
        switch tab {
        case .sections: return "list.bullet.rectangle"
        case .files: return "doc.text"
        case .details: return "info.circle"
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .sections:
            sectionsTab
        case .files:
            filesTab
        case .details:
            detailsTab
        }
    }

    // MARK: - Sections Tab

    private var sectionsTab: some View {
        LazyVStack(spacing: SBSpacing.md) {
            if course?.sections.isEmpty == true {
                SBEmptyState(
                    icon: "folder.badge.plus",
                    title: "Bu derste henüz bölüm yok",
                    message: "Bölüm ekleyerek dosyalarını düzenlemeye başlayabilirsin."
                )
            } else if let sections = course?.sections {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    sectionCard(section: section, index: index)
                }
            }
        }
    }

    private func sectionCard(section: DriveSection, index: Int) -> some View {
        SBCommandCard(tint: Color(hex: section.iconColorHex), action: {
            router.navigate(to: .folder(courseId: courseId, sectionId: section.id))
        }) {
                VStack(alignment: .leading, spacing: SBSpacing.md) {
                    HStack(spacing: SBSpacing.md) {
                        SBIconTile(icon: section.iconName, tint: Color(hex: section.iconColorHex), size: 42, radius: 12)

                        VStack(alignment: .leading, spacing: SBSpacing.xs) {
                            Text(section.title)
                                .font(SBTypography.titleSmall)
                                .foregroundStyle(SBColors.navy)
                                .lineLimit(1)

                            HStack(spacing: SBSpacing.sm) {
                                Text(section.status == .draft ? "Beklemede" : "Aktif")
                                    .font(SBTypography.caption)
                                    .foregroundStyle(section.status == .draft ? SBColors.blue : SBColors.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(section.status == .draft ? SBColors.selectedBlue : SBColors.greenBg)
                                    .clipShape(Capsule())

                                Text("\(section.files.count) dosya")
                                    .font(SBTypography.caption)
                                    .foregroundStyle(SBColors.muted)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .sbScaledFont(size: 14, weight: .semibold)
                            .foregroundStyle(SBColors.softText)
                    }

                    if !section.files.isEmpty {
                        FlowLayout(spacing: SBSpacing.xs) {
                            ForEach(section.files.prefix(3)) { file in
                                miniFileChip(file: file)
                            }
                            if section.files.count > 3 {
                                Text("+\(section.files.count - 3)")
                                    .font(SBTypography.caption)
                                    .foregroundStyle(SBColors.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(SBColors.selectedBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    } else {
                        Text("Henüz dosya yok")
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)
                    }
                }
        }
        .contextMenu {
            Button("Aç", systemImage: "folder") {
                router.navigate(to: .folder(courseId: courseId, sectionId: section.id))
            }
            Button("Yeniden adlandır", systemImage: "pencil") {
                sectionRenameTitle = section.title
                sectionPendingRename = section
            }
            Button("Sil", systemImage: "trash", role: .destructive) {
                sectionPendingDelete = section
            }
        }
    }

    private func miniFileChip(file: DriveFile) -> some View {
        HStack(spacing: 4) {
            Text(SBFileKind.from(file.kind).label)
                .sbScaledFont(size: 9, weight: .bold)
                .foregroundStyle(SBFileKind.from(file.kind).color)

            Text(file.title)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(SBColors.line, lineWidth: 1)
        )
    }

    // MARK: - Files Tab

    private var filesTab: some View {
        LazyVStack(spacing: SBSpacing.md) {
            if allFiles.isEmpty {
                SBEmptyState(
                    icon: "doc.badge.plus",
                    title: "Bu derste henüz dosya yok",
                    message: "\(DriveUploadService.supportedExtensionsDisplay) yükleyerek başlayabilirsin."
                )
            } else {
                ForEach(allFiles) { file in
                    SBFileCard(
                        title: file.title,
                        kind: SBFileKind.from(file.kind),
                        status: SBStatus.from(file.status),
                        sizeLabel: file.sizeLabel,
                        courseTitle: file.courseTitle,
                        updatedLabel: file.updatedLabel
                    ) {
                        router.navigate(to: .fileDetail(fileId: file.id))
                    }
                }
            }
        }
    }

    // MARK: - Details Tab

    private var detailsTab: some View {
        VStack(spacing: SBSpacing.md) {
            SBCard {
                VStack(alignment: .leading, spacing: SBSpacing.lg) {
                    detailRow(label: "Ders adı", value: course?.title ?? "-")
                    detailRow(label: "Durum", value: course?.status == .draft ? "Beklemede" : "Aktif")
                    detailRow(label: "Bölüm sayısı", value: "\(course?.sections.count ?? 0)")
                    detailRow(label: "Dosya sayısı", value: "\(course?.fileCount ?? 0)")
                    detailRow(label: "Son güncelleme", value: course?.updatedLabel ?? "-")
                }
            }

            SBCard {
                VStack(alignment: .leading, spacing: SBSpacing.md) {
                    HStack(spacing: SBSpacing.sm) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(SBColors.blue)
                        Text("Açıklama")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                    }

                    Text(course?.description ?? "Açıklama bulunmuyor.")
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.navy)
                        .lineSpacing(4)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Loading

    private func loadCourse() async {
        await workspaceStore.loadWorkspace()
    }
}

#Preview {
    NavigationStack {
        CourseDetailView(courseId: "test-id")
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
