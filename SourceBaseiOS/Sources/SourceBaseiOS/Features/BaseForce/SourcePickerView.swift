import SwiftUI
import SourceBaseBackend

struct SourcePickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var selectedSources: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var selectedCourseFilterId: String?
    @State private var selectedSectionFilterId: String?

    private var router: AppRouter { appState.router }
    private var allFiles: [DriveFile] { workspaceStore.allFiles }

    private var readyCount: Int {
        allFiles.filter { isReadySource($0) }.count
    }

    private var processingCount: Int {
        allFiles.filter { $0.status == .processing || $0.status == .uploading }.count
    }

    private var blockedCount: Int {
        allFiles.count - readyCount - processingCount
    }

    private var filteredFiles: [DriveFile] {
        var files = allFiles
        if let selectedCourseFilterId,
           let course = workspaceStore.course(id: selectedCourseFilterId) {
            let ids = Set(course.sections.flatMap(\.files).map(\.id))
            files = files.filter { ids.contains($0.id) }
        }
        if let selectedSectionFilterId,
           let section = workspaceStore.section(id: selectedSectionFilterId) {
            let ids = Set(section.files.map(\.id))
            files = files.filter { ids.contains($0.id) }
        }
        guard !searchQuery.isEmpty else { return files }
        let query = searchQuery.lowercased()
        return files.filter { file in
            file.title.lowercased().contains(query) ||
            file.courseTitle.lowercased().contains(query) ||
            file.sectionTitle.lowercased().contains(query)
        }
    }

    private var filteredReadyCount: Int {
        filteredFiles.filter { isReadySource($0) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "folder",
                        title: "Kaynaklar yükleniyor",
                        message: "Drive dosyaları hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Kaynaklar yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadWorkspace() } }
                    )
                } else {
                    heroCard.sbEntrance(0)
                    selectionGuide.sbEntrance(1)
                    searchBox.sbEntrance(2)
                    sourceFilters.sbEntrance(3)
                    filesSection.sbEntrance(4)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding(160)
            .sbReadableWidth(720)
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle("Kaynak Seç")
        .sbInlineNavTitle()
        .safeAreaInset(edge: .bottom) {
            selectedTray
        }
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        SBSignatureHero(
            eyebrow: "Ders kaynağı",
            title: "Hangi nottan çalışacaksın?",
            message: selectedSources.isEmpty ? "Hazır kaynağı seç. Sonraki ekranda üretim türünü aç." : "\(selectedSources.count) kaynak seçildi. Şimdi çalışma türünü seç.",
            icon: "doc.text.magnifyingglass",
            tint: SBColors.blue
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "checkmark.circle", value: "\(readyCount)", label: "hazır", tint: SBColors.green),
                .init(icon: "hourglass", value: "\(processingCount)", label: "işleniyor", tint: SBColors.orange),
                .init(icon: "xmark.circle", value: "\(blockedCount)", label: "uygun değil", tint: SBColors.red)
            ])
        }
    }

    private var selectionGuide: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    Image(systemName: selectedSources.isEmpty ? "hand.tap" : "checkmark.seal.fill")
                        .sbScaledFont(size: 18, weight: .semibold)
                        .foregroundStyle(selectedSources.isEmpty ? SBColors.blue : SBColors.green)
                        .accessibilityHidden(true)

                    Text(selectedSources.isEmpty ? "Sınav konuna en yakın hazır kaynağı seç" : "Seçim hazır")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    guideChip(title: "Konu", value: filterSummary, icon: "books.vertical", tint: SBColors.purple, isActive: selectedCourseFilterId != nil)
                    guideChip(title: "Kaynak", value: selectedSources.isEmpty ? "Seçilmedi" : "\(selectedSources.count) seçili", icon: "doc.text", tint: selectedSources.isEmpty ? SBColors.orange : SBColors.green, isActive: true)
                    guideChip(title: "Sonra", value: "Kart, soru, özet", icon: "bolt.fill", tint: SBColors.blue, isActive: !selectedSources.isEmpty)
                }
            }
        }
    }

    private var sourceFilters: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    SBIconTile(icon: "line.3.horizontal.decrease.circle", tint: SBColors.blue, size: 34, radius: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ders / bölüm")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Text(filterSummary)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                FlowLayout(spacing: SBSpacing.sm) {
                    filterChip(title: "Tüm dersler", isSelected: selectedCourseFilterId == nil, tint: SBColors.blue) {
                        selectedCourseFilterId = nil
                        selectedSectionFilterId = nil
                    }
                    ForEach(workspaceStore.workspace.courses.filter { $0.fileCount > 0 }) { course in
                        filterChip(title: course.title, isSelected: selectedCourseFilterId == course.id, tint: SBColors.purple) {
                            selectedCourseFilterId = course.id
                            selectedSectionFilterId = nil
                        }
                    }
                }

                if let course = workspaceStore.course(id: selectedCourseFilterId),
                   !course.sections.isEmpty {
                    FlowLayout(spacing: SBSpacing.sm) {
                        filterChip(title: "Tüm bölümler", isSelected: selectedSectionFilterId == nil, tint: SBColors.blue) {
                            selectedSectionFilterId = nil
                        }
                        ForEach(course.sections.filter { !$0.files.isEmpty }) { section in
                            filterChip(title: section.title, isSelected: selectedSectionFilterId == section.id, tint: SBColors.green) {
                                selectedSectionFilterId = section.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var filterSummary: String {
        let course = workspaceStore.course(id: selectedCourseFilterId)?.title
        let section = workspaceStore.section(id: selectedSectionFilterId)?.title
        switch (course, section) {
        case let (.some(course), .some(section)): return "\(course) / \(section)"
        case let (.some(course), .none): return "\(course) içindeki kaynaklar"
        default: return "Tüm Drive kaynakları"
        }
    }

    // MARK: - Search Box

    private var searchBox: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "magnifyingglass")
                .sbScaledFont(size: 18)
                .foregroundStyle(SBColors.muted)

            TextField("Ders, bölüm veya kaynak ara", text: $searchQuery)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .submitLabel(.search)
                .accessibilityLabel("Kaynak ara")
        }
        .padding(.horizontal, SBSpacing.md)
        .frame(height: 48)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    // MARK: - Files Section

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            HStack {
                Text("Kaynaklar")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)

                Spacer()

                Text(searchQuery.isEmpty ? "\(readyCount) hazır" : "\(filteredReadyCount) hazır")
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.muted)
            }

            SBCard(padding: 0, radius: 16) {
                if allFiles.isEmpty {
                    SBEmptyState(
                        icon: "folder.badge.plus",
                        title: "Önce bir kaynak yükle",
                        message: "Drive'a dosya ekle, sonra buradan seç.",
                        badges: ["PDF", "PPTX", "DOCX"],
                        actionLabel: "Drive'a git",
                        onAction: {
                            router.sourcePickerDestination = nil
                            router.switchTab(to: .drive)
                        }
                    )
                } else {
                    VStack(spacing: 0) {
                        if filteredFiles.isEmpty {
                            SBEmptyState(
                                icon: "magnifyingglass",
                                title: "Sonuç yok",
                                message: "Aramayı kısalt veya Drive'daki ders adına göre dene.",
                                badges: [],
                                actionLabel: "Aramayı temizle",
                                onAction: { searchQuery = "" }
                            )
                        } else {
                            ForEach(Array(filteredFiles.enumerated()), id: \.element.id) { index, file in
                                sourceRow(file: file)

                                if index < filteredFiles.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sourceRow(file: DriveFile) -> some View {
        let isSelected = selectedSources.contains(file.id)
        let isReady = isReadySource(file)

        return Button {
            if isReady {
                SBHaptics.selection()
                toggleSource(file.id)
            }
        } label: {
            HStack(spacing: SBSpacing.md) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected && isReady ? SBColors.blue : SBColors.white)
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isReady ? SBColors.blue : SBColors.muted.opacity(0.3), lineWidth: 1.5)
                        )

                    if isSelected && isReady {
                        Image(systemName: "checkmark")
                            .sbScaledFont(size: 16, weight: .bold)
                            .foregroundStyle(.white)
                    }
                }

                SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

                VStack(alignment: .leading, spacing: SBSpacing.xs) {
                    Text(file.title)
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(2)

                    FlowLayout(spacing: SBSpacing.sm) {
                        SBStatusBadge(status: SBStatus.from(file.status), compact: true)
                        sourceContextChip(file)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                if isReady {
                    VStack(alignment: .trailing, spacing: SBSpacing.xs) {
                            Text(isSelected ? "Seçili" : "Seç")
                            .font(SBTypography.caption)
                            .foregroundStyle(isSelected ? SBColors.blue : SBColors.muted)
                            .lineLimit(1)
                            .fixedSize()
                        if !isSelected {
                            Text("üretime hazır")
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.softText)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                } else {
                    VStack(alignment: .trailing, spacing: SBSpacing.xs) {
                        Image(systemName: "lock.fill")
                            .sbScaledFont(size: 16)
                            .foregroundStyle(SBColors.muted)
                        Text(file.status == .processing || file.status == .uploading ? "İşleniyor" : "Hazır değil")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.softText)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
            .padding(SBSpacing.md)
            .opacity(isReady ? 1.0 : 0.6)
            .background(isSelected ? SBColors.selectedBlue.opacity(0.72) : Color.clear)
            .sbSelectionDelight(isSelected)
        }
        .buttonStyle(SBPressStyle())
        .disabled(!isReady)
        .accessibilityHint(isReady ? "Kaynağı seçer veya seçimden çıkarır" : "Bu kaynak işlenmeden üretime alınamaz")
    }

    // MARK: - Selected Tray

    @ViewBuilder
    private var selectedTray: some View {
        if !selectedSources.isEmpty {
            HStack(spacing: SBSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedSources.count) kaynak seçildi")
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.navy)
                    Text(selectedTraySubtitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }

                Spacer()

                SBButton(
                    "Çalışma türünü seç",
                    icon: "arrow.right",
                    variant: .primary,
                    size: .small,
                    action: continueWithSelection
                )
            }
            .padding(.horizontal, SBSpacing.lg)
            .padding(.vertical, SBSpacing.md)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle().fill(SBColors.softLine).frame(height: 0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(selectedSources.count) kaynak seçildi. Çalışma türünü seç.")
        }
    }

    // MARK: - Helpers

    private func isReadySource(_ file: DriveFile) -> Bool {
        workspaceStore.isReadyForGeneration(file)
    }

    private func toggleSource(_ fileId: String) {
        if selectedSources.contains(fileId) {
            selectedSources.remove(fileId)
        } else {
            selectedSources.insert(fileId)
        }
    }

    private func continueWithSelection() {
        workspaceStore.setSelectedSources(selectedSources)
        if let first = filteredFiles.first(where: { selectedSources.contains($0.id) }) {
            workspaceStore.selectFile(first)
        }
        router.completeSourceSelection()
    }

    private func loadWorkspace() async {
        isLoading = true
        errorMessage = nil
        await workspaceStore.loadWorkspace()
        selectedSources = workspaceStore.selectedSourceIds
        errorMessage = workspaceStore.errorMessage
        isLoading = false
    }

    private func guideChip(title: String, value: String, icon: String, tint: Color, isActive: Bool) -> some View {
        HStack(spacing: SBSpacing.sm) {
            Image(systemName: icon)
                .sbScaledFont(size: 15, weight: .semibold)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)
                Text(value)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(SBSpacing.sm)
        .background(isActive ? tint.opacity(0.08) : SBColors.field.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? tint.opacity(0.18) : SBColors.softLine, lineWidth: 1)
        )
    }

    private func sourceContextChip(_ file: DriveFile) -> some View {
        Text(sourceContextLabel(file))
            .font(SBTypography.caption)
            .foregroundStyle(SBColors.purple)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SBColors.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func sourceContextLabel(_ file: DriveFile) -> String {
        let course = file.courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = file.sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !course.isEmpty && !section.isEmpty {
            return "\(course) / \(section)"
        }
        return course.isEmpty ? section : course
    }

    private var selectedTraySubtitle: String {
        if let first = filteredFiles.first(where: { selectedSources.contains($0.id) }) {
            return sourceContextLabel(first)
        }
        return "Çalışma türünü seçmeye hazırsın"
    }

    private func filterChip(title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            SBHaptics.selection()
            action()
        } label: {
            Text(title)
                .font(SBTypography.labelSmall)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
                .lineLimit(1)
                .padding(.horizontal, SBSpacing.md)
                .padding(.vertical, SBSpacing.sm)
                .background(isSelected ? tint : SBColors.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? tint : SBColors.softLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }
}

#Preview {
    NavigationStack {
        SourcePickerView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
