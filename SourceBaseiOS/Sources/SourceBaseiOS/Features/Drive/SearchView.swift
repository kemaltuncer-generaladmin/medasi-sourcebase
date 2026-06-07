import SwiftUI
import SourceBaseBackend

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var query = ""
    @State private var kindFilter: SBFileKind?
    @State private var statusFilter: SBStatus?
    @State private var courseFilter: String?
    @State private var sectionFilter: String?
    @State private var featuredOnly = false
    @State private var sortOrder: SearchSort = .newest
    @FocusState private var isSearchFocused: Bool

    private var router: AppRouter { appState.router }
    private var files: [DriveFile] { workspaceStore.allFiles }

    enum SearchSort: String, CaseIterable {
        case newest = "En yeni"
        case name = "Ada göre"
        case course = "Derse göre"
    }

    private var courses: [String] {
        Array(Set(files.map { $0.courseTitle })).sorted()
    }

    private var sections: [String] {
        let filtered = courseFilter == nil ? files : files.filter { $0.courseTitle == courseFilter }
        return Array(Set(filtered.map { $0.sectionTitle })).sorted()
    }

    private var statuses: [SBStatus] {
        [.ready, .processing, .uploading, .failed, .draft]
    }

    private var hasFilters: Bool {
        !query.isEmpty || kindFilter != nil || statusFilter != nil ||
        courseFilter != nil || sectionFilter != nil || featuredOnly || sortOrder != .newest
    }

    private var results: [DriveFile] {
        let queryLower = query.lowercased()
        let filtered = files.filter { file in
            let matchesQuery = queryLower.isEmpty ||
                file.title.lowercased().contains(queryLower) ||
                file.courseTitle.lowercased().contains(queryLower) ||
                file.sectionTitle.lowercased().contains(queryLower) ||
                (file.tag?.lowercased().contains(queryLower) ?? false)

            return matchesQuery &&
                (kindFilter == nil || SBFileKind.from(file.kind) == kindFilter) &&
                (statusFilter == nil || SBStatus.from(file.status) == statusFilter) &&
                (courseFilter == nil || file.courseTitle == courseFilter) &&
                (sectionFilter == nil || file.sectionTitle == sectionFilter) &&
                (!featuredOnly || file.featured || file.selected)
        }

        switch sortOrder {
        case .newest: return filtered
        case .name: return filtered.sorted { $0.title < $1.title }
        case .course: return filtered.sorted { "\($0.courseTitle)\($0.sectionTitle)\($0.title)" < "\($1.courseTitle)\($1.sectionTitle)\($1.title)" }
        }
    }

    private var readyCount: Int {
        files.filter { $0.status == .completed }.count
    }

    private var processingCount: Int {
        files.filter { $0.status == .processing || $0.status == .uploading }.count
    }

    private var dynamicSuggestions: [String] {
        var suggestions: [String] = []
        suggestions.append(contentsOf: courses.prefix(2))
        if readyCount > 0 { suggestions.append("Hazır kaynaklar") }
        if files.contains(where: { $0.kind == .pptx }) { suggestions.append("PPTX") }
        if files.contains(where: { $0.kind == .pdf }) { suggestions.append("PDF") }
        suggestions.append(contentsOf: files.compactMap(\.tag).prefix(2))
        return Array(NSOrderedSet(array: suggestions)) as? [String] ?? suggestions
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SBSpacing.lg) {
                if workspaceStore.isLoading {
                    SBLoadingState(
                        icon: "magnifyingglass",
                        title: "Arama hazırlanıyor",
                        message: "Dosyalar yükleniyor..."
                    )
                } else if let error = workspaceStore.errorMessage {
                    SBErrorState(
                        title: "Arama yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await workspaceStore.refresh() } }
                    )
                } else {
                    headerSection.sbEntrance(0)
                    searchInput.sbEntrance(1)
                    suggestedQueries.sbEntrance(2)
                    filterBar.sbEntrance(3)
                    if hasFilters {
                        resultHeader.sbEntrance(4)
                    }
                    resultsList.sbEntrance(5)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle("Arama")
        .task {
            await workspaceStore.loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "Arama",
            title: "Kaynak bul",
            message: "\(files.count) kaynak içinde ara.",
            icon: "magnifyingglass",
            tint: SBColors.cyan
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "checkmark.circle", value: "\(readyCount)", label: "hazır", tint: SBColors.green),
                .init(icon: "arrow.triangle.2.circlepath", value: "\(processingCount)", label: "işleniyor", tint: SBColors.orange),
                .init(icon: "line.3.horizontal.decrease.circle", value: hasFilters ? "\(results.count)" : "-", label: "sonuç", tint: SBColors.cyan)
            ])
        }
    }

    // MARK: - Stats Strip

    // MARK: - Search Input

    private var searchInput: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "magnifyingglass")
                .sbScaledFont(size: 18, weight: .medium)
                .foregroundStyle(SBColors.navy)

            TextField("Ara...", text: $query)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                .focused($isSearchFocused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .submitLabel(.search)
                .accessibilityLabel("Drive içinde ara")
                .onAppear {
                    isSearchFocused = true
                }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .sbScaledFont(size: 18)
                        .foregroundStyle(SBColors.muted)
                }
                .accessibilityLabel("Aramayı temizle")
            }
        }
        .padding(.horizontal, SBSpacing.md)
        .frame(height: 48)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(isSearchFocused ? SBColors.blue : SBColors.blue.opacity(0.5), lineWidth: isSearchFocused ? 2 : 1)
        )
    }

    // MARK: - Suggested Queries

    private var suggestedQueries: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SBSpacing.sm) {
                ForEach(dynamicSuggestions, id: \.self) { suggestion in
                    suggestedChip(suggestion)
                }
            }
        }
    }

    private func suggestedChip(_ text: String) -> some View {
        Button {
            applySuggestion(text)
        } label: {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: "arrow.up.left")
                    .sbScaledFont(size: 12, weight: .semibold)

                Text(text)
                    .font(SBTypography.caption)
            }
            .foregroundStyle(SBColors.navy)
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(SBColors.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(SBColors.softLine, lineWidth: 1)
            )
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SBSpacing.sm) {
                Menu {
                    Button("Tüm Dersler") {
                        courseFilter = nil
                        sectionFilter = nil
                    }

                    ForEach(courses, id: \.self) { course in
                        Button {
                            courseFilter = course
                            sectionFilter = nil
                        } label: {
                            Label(course, systemImage: courseFilter == course ? "checkmark" : "book")
                        }
                    }
                } label: {
                    filterMenuLabel(icon: "book", label: courseFilter ?? "Ders", isActive: courseFilter != nil)
                }

                Menu {
                    Button("Tüm Bölümler") {
                        sectionFilter = nil
                    }

                    ForEach(sections, id: \.self) { section in
                        Button {
                            sectionFilter = section
                        } label: {
                            Label(section, systemImage: sectionFilter == section ? "checkmark" : "list.bullet")
                        }
                    }
                } label: {
                    filterMenuLabel(icon: "list.bullet", label: sectionFilter ?? "Bölüm", isActive: sectionFilter != nil)
                }

                Menu {
                    Button("Tüm Türler") {
                        kindFilter = nil
                    }

                    ForEach([SBFileKind.pdf, .pptx, .docx, .ppt, .doc, .zip], id: \.self) { kind in
                        Button {
                            kindFilter = kind
                        } label: {
                            Label(kind.label, systemImage: kindFilter == kind ? "checkmark" : "doc")
                        }
                    }
                } label: {
                    filterMenuLabel(icon: "doc", label: kindFilter?.label ?? "Tür", isActive: kindFilter != nil)
                }

                Menu {
                    Button("Tüm Durumlar") {
                        statusFilter = nil
                    }

                    ForEach(statuses, id: \.self) { status in
                        Button {
                            statusFilter = status
                        } label: {
                            Label(status.label, systemImage: statusFilter == status ? "checkmark" : status.iconName)
                        }
                    }
                } label: {
                    filterMenuLabel(icon: "arrow.triangle.2.circlepath", label: statusFilter?.label ?? "Durum", isActive: statusFilter != nil)
                }

                filterPill(icon: "star", label: "Favori", isActive: featuredOnly) {
                    featuredOnly.toggle()
                }

                if hasFilters {
                    filterPill(icon: "xmark", label: "Temizle", isActive: true) {
                        clearFilters()
                    }
                }
            }
        }
    }

    private func filterMenuLabel(icon: String, label: String, isActive: Bool) -> some View {
        HStack(spacing: SBSpacing.xs) {
            Image(systemName: icon)
                .sbScaledFont(size: 14, weight: .semibold)
                .foregroundStyle(isActive ? SBColors.blue : SBColors.muted)

            Text(label)
                .font(SBTypography.caption)
                .foregroundStyle(isActive ? SBColors.blue : SBColors.navy)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .sbScaledFont(size: 10, weight: .semibold)
                .foregroundStyle(isActive ? SBColors.blue : SBColors.softText)
        }
        .padding(.horizontal, SBSpacing.sm)
        .padding(.vertical, SBSpacing.sm)
        .background(isActive ? SBColors.selectedBlue : SBColors.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? SBColors.blue.opacity(0.22) : SBColors.softLine, lineWidth: 1)
        )
    }

    private func filterPill(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(isActive ? SBColors.blue : SBColors.muted)

                Text(label)
                    .font(SBTypography.caption)
                    .foregroundStyle(isActive ? SBColors.blue : SBColors.navy)
                    .lineLimit(1)
            }
            .padding(.horizontal, SBSpacing.sm)
            .padding(.vertical, SBSpacing.sm)
            .background(isActive ? SBColors.selectedBlue : SBColors.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? SBColors.blue.opacity(0.22) : SBColors.softLine, lineWidth: 1)
            )
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        HStack {
            Text("\(results.count) sonuç bulundu")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)

            Spacer()

            Menu {
                ForEach(SearchSort.allCases, id: \.self) { sort in
                    Button {
                        sortOrder = sort
                    } label: {
                        HStack {
                            Text(sort.rawValue)
                            if sortOrder == sort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: SBSpacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                        .sbScaledFont(size: 14)

                    Text(sortOrder.rawValue)
                        .font(SBTypography.labelSmall)
                }
                .foregroundStyle(SBColors.navy)
                .padding(.horizontal, SBSpacing.md)
                .padding(.vertical, SBSpacing.sm)
                .background(SBColors.selectedBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(SBColors.softLine, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Results List

    @ViewBuilder
    private var resultsList: some View {
        if !hasFilters {
            SBEmptyState(
                icon: "magnifyingglass",
                title: "Ara",
                message: "Dosya, ders veya bölüm yaz.",
                badges: ["Hazır kaynaklar", "PPTX sunumlar", "Flashcard çıktıları"]
            )
        } else if results.isEmpty {
            SBEmptyState(
                icon: "magnifyingglass",
                title: "Sonuç yok",
                message: "Aramayı veya filtreleri değiştir.",
                badges: ["Filtreleri temizle", "Hazır kaynakları göster"],
                actionLabel: "Filtreleri temizle",
                onAction: clearFilters
            )
        } else {
            LazyVStack(spacing: SBSpacing.md) {
                ForEach(results) { file in
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

    // MARK: - Actions

    private func clearFilters() {
        query = ""
        kindFilter = nil
        statusFilter = nil
        courseFilter = nil
        sectionFilter = nil
        featuredOnly = false
        sortOrder = .newest
    }

    private func applySuggestion(_ text: String) {
        clearFilters()
        switch text {
        case "Hazır kaynaklar":
            statusFilter = .ready
        case "PPTX":
            kindFilter = .pptx
        case "PDF":
            kindFilter = .pdf
        default:
            query = text
        }
    }

}

#Preview {
    NavigationStack {
        SearchView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
