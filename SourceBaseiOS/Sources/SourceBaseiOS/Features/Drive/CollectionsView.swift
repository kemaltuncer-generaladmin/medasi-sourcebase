import SwiftUI
import SourceBaseBackend

struct CollectionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var collections: [CollectionBundle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedKind: GeneratedKind?
    @State private var sortOrder: CollectionSort = .newest

    private var router: AppRouter { appState.router }

    enum CollectionSort: String, CaseIterable {
        case newest = "Yeni"
        case name = "A-Z"
        case outputCount = "Çok çalışma"
    }

    private var filteredCollections: [CollectionBundle] {
        let filtered = selectedKind == nil
            ? collections
            : collections.filter { bundle in
                bundle.outputs.contains { $0.kind == selectedKind }
            }

        switch sortOrder {
        case .newest: return filtered
        case .name: return filtered.sorted { $0.file.title < $1.file.title }
        case .outputCount: return filtered.sorted { $0.outputs.count > $1.outputs.count }
        }
    }

    private func count(_ kind: GeneratedKind) -> Int {
        collections.reduce(0) { total, bundle in
            total + bundle.outputs.filter { $0.kind == kind }.count
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "rectangle.stack",
                        title: "Hazırlanıyor",
                        message: "Çalışmalar yükleniyor."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Koleksiyonlar yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadCollections() } }
                    )
                } else {
                    headerSection
                    statsStrip
                    filterBar
                    sortSection
                    collectionsList
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle("Koleksiyonlar")
        .task {
            await loadCollections()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.xs) {
            Text("Kart, soru ve özetler.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        SBCard(radius: 16) {
            HStack(spacing: SBSpacing.md) {
                statItem(icon: "folder", value: "\(collections.count)", label: "Kaynak", color: SBColors.blue)

                Divider().frame(height: 34)

                statItem(icon: "rectangle.on.rectangle", value: "\(count(.flashcard))", label: "Kart", color: SBColors.green)

                Divider().frame(height: 34)

                statItem(icon: "questionmark.circle", value: "\(count(.question))", label: "Soru", color: SBColors.questionTint)

                Divider().frame(height: 34)

                statItem(icon: "doc.text", value: "\(count(.summary))", label: "Özet", color: SBColors.purple)
            }
        }
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: SBSpacing.xs) {
            Image(systemName: icon)
                .sbScaledFont(size: 16, weight: .semibold)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(SBColors.navy)

                Text(label)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SBSpacing.sm) {
                filterChip(label: "Tümü", icon: nil, kind: nil)
                filterChip(label: "Kart", icon: "rectangle.on.rectangle", kind: .flashcard)
                filterChip(label: "Soru", icon: "questionmark.circle", kind: .question)
                filterChip(label: "Özet", icon: "doc.text", kind: .summary)
                filterChip(label: "Tablo", icon: "tablecells", kind: .table)
                filterChip(label: "Podcast", icon: "headphones", kind: .podcast)
            }
        }
    }

    private func filterChip(label: String, icon: String?, kind: GeneratedKind?) -> some View {
        let isSelected = selectedKind == kind

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedKind = kind
            }
        } label: {
            HStack(spacing: SBSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .sbScaledFont(size: 14, weight: .semibold)
                }

                Text(label)
                    .font(SBTypography.labelSmall)
            }
            .foregroundStyle(isSelected ? .white : SBColors.navy)
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? SBColors.blue : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? SBColors.blue : SBColors.softLine, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        HStack {
            Text("Kaynaklar")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            Spacer()

            Menu {
                ForEach(CollectionSort.allCases, id: \.self) { sort in
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
                    Text(sortOrder.rawValue)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.blue)

                    Image(systemName: "chevron.down")
                        .sbScaledFont(size: 10, weight: .semibold)
                        .foregroundStyle(SBColors.blue)
                }
            }
        }
    }

    // MARK: - Collections List

    @ViewBuilder
    private var collectionsList: some View {
        if collections.isEmpty {
            SBEmptyState(
                icon: "rectangle.stack.badge.plus",
                title: "Henüz koleksiyon yok",
                message: "Kart, soru veya özet üretince burada çalışırsın.",
                badges: ["Kart", "Soru", "Özet"],
                actionLabel: "Kaynak seçip üret",
                onAction: { router.beginSourceSelection(from: .baseForce, destination: .baseForceHome) }
            )
        } else if filteredCollections.isEmpty {
            SBEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: "Bu filtrede koleksiyon yok",
                message: "Başka bir filtre seç veya yeni çalışma başlat.",
                badges: ["Yeni üretim"],
                actionLabel: "Filtreyi temizle",
                onAction: { selectedKind = nil }
            )
        } else {
            LazyVStack(spacing: SBSpacing.md) {
                ForEach(filteredCollections, id: \.file.id) { bundle in
                    collectionCard(bundle)
                }
            }
        }
    }

    // MARK: - Collection Card

    private func collectionCard(_ bundle: CollectionBundle) -> some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                // Header
                HStack(alignment: .top, spacing: SBSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(outputColor(bundle.previewKind).opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: outputIcon(bundle.previewKind))
                            .sbScaledFont(size: 20)
                            .foregroundStyle(outputColor(bundle.previewKind))
                    }

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(bundle.file.title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .lineLimit(2)

                        Text(bundle.subject)
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !bundle.outputs.isEmpty {
                        SBStatusBadge(status: .ready, compact: true)
                    }

                    Menu {
                        Button {
                            openFile(bundle.file)
                        } label: {
                            Label("Kaynağı Aç", systemImage: "arrow.up.right.square")
                        }

                        Divider()

                        Button {
                            generate(from: bundle.file, kind: .flashcard)
                        } label: {
                            Label("Flashcard üret", systemImage: "rectangle.on.rectangle")
                        }

                        Button {
                            generate(from: bundle.file, kind: .question)
                        } label: {
                            Label("Soru üret", systemImage: "questionmark.circle")
                        }

                        Button {
                            generate(from: bundle.file, kind: .summary)
                        } label: {
                            Label("Özet üret", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .sbScaledFont(size: 16, weight: .semibold)
                            .foregroundStyle(SBColors.muted)
                            .frame(width: 44, height: 44)
                    }
                }

                // Info pills
                FlowLayout(spacing: SBSpacing.xs) {
                    infoPill(icon: "graduationcap", text: bundle.subject)
                    infoPill(icon: "square.stack.3d.up", text: "\(bundle.outputs.count) çalışma")
                    infoPill(icon: "doc", text: SBFileKind.from(bundle.file.kind).label)
                    infoPill(icon: "clock", text: bundle.file.updatedLabel)
                }

                // Outputs
                if !bundle.outputs.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(bundle.outputs.prefix(3).enumerated()), id: \.element.id) { index, output in
                            Button {
                                router.navigate(to: .studyOutput(outputId: output.id))
                            } label: {
                                outputRow(output)
                            }
                            .buttonStyle(.plain)

                            if index < min(bundle.outputs.count, 3) - 1 {
                                Divider()
                            }
                        }
                    }
                }

                // Actions
                HStack {
                    Button {
                        openFile(bundle.file)
                    } label: {
                        HStack(spacing: SBSpacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                                .sbScaledFont(size: 14)
                            Text("Kaynağı aç")
                                .font(SBTypography.labelSmall)
                        }
                        .foregroundStyle(SBColors.blue)
                    }

                    Spacer()

                    Button {
                        generate(from: bundle.file, kind: bundle.previewKind)
                    } label: {
                        HStack(spacing: SBSpacing.xs) {
                            Image(systemName: "bolt.fill")
                                .sbScaledFont(size: 14)
                            Text("Benzer çalışma üret")
                                .font(SBTypography.labelSmall)
                        }
                        .foregroundStyle(outputColor(bundle.previewKind))
                    }
                }
            }
        }
    }

    private func infoPill(icon: String, text: String) -> some View {
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

    private func outputRow(_ output: GeneratedOutput) -> some View {
        HStack(spacing: SBSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(outputColor(output.kind).opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: outputIcon(output.kind))
                    .sbScaledFont(size: 16)
                    .foregroundStyle(outputColor(output.kind))
            }

            VStack(alignment: .leading, spacing: SBSpacing.xs) {
                Text(output.title)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)

                Text(output.detail)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(output.updatedLabel)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.softText)
        }
        .padding(.vertical, SBSpacing.sm)
    }

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
        case .algorithm: return SBColors.green
        case .comparison, .table: return SBColors.orange
        case .clinicalScenario: return SBColors.orange
        case .learningPlan: return SBColors.green
        case .podcast: return SBColors.red
        case .infographic: return SBColors.cyan
        case .mindMap: return SBColors.navy
        }
    }

    // MARK: - Actions

    private func loadCollections() async {
        isLoading = true
        errorMessage = nil

        await workspaceStore.loadWorkspace()
        collections = workspaceStore.workspace.collections
        errorMessage = workspaceStore.errorMessage

        isLoading = false
    }

    private func openFile(_ file: DriveFile) {
        workspaceStore.selectFile(file)
        router.navigate(to: .fileDetail(fileId: file.id))
    }

    private func generate(from file: DriveFile, kind: GeneratedKind) {
        guard workspaceStore.isReadyForGeneration(file) else {
            workspaceStore.toast("Bu kaynak hazır olmadan üretime alınamaz.")
            return
        }

        Task {
            _ = await workspaceStore.enqueueDriveGeneration(file: file, kind: kind)
            router.navigate(to: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
        }
    }
}

#Preview {
    NavigationStack {
        CollectionsView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
