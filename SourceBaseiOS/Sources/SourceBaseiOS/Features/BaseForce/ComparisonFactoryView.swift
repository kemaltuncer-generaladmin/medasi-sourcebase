import SwiftUI
import SourceBaseBackend

struct ComparisonFactoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var comparisonType: ComparisonType = .disease
    @State private var tableFormat: TableFormat = .classicTable
    @State private var detailLevel: DetailLevel = .balanced
    @State private var qualityTier: QualityTier = .standard

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }

    enum ComparisonType: String, CaseIterable {
        case disease = "Hastalık"
        case drug = "İlaç"
        case mechanism = "Mekanizma"
        case clinicalFinding = "Klinik bulgu"
        case diagnosisTreatment = "Tanı-tedavi"
        case basicScience = "Temel bilim"
        case tusConfusables = "TUS tuzakları"
    }

    enum TableFormat: String, CaseIterable {
        case classicTable = "Klasik"
        case columnBased = "Sütun"
        case distinguishingClue = "İpucu"
        case diagnosisTestTreatment = "Tanı-tedavi"
        case plusMinus = "Artı-eksi"
        case miniSummaryPlusTable = "Özet + tablo"
    }

    enum DetailLevel: String, CaseIterable {
        case brief = "Kısa"
        case balanced = "Dengeli"
        case detailed = "Detaylı"
        case clinical = "Klinik odaklı"
        case exam = "Sınav odaklı"
    }

    enum QualityTier: String, CaseIterable {
        case economy = "Ekonomik"
        case standard = "Standart"
        case premium = "Premium"
    }

    private var selectedFiles: [DriveFile] {
        workspaceStore.allFiles.filter { file in
            selectedSources.contains(file.id) && isReadySource(file)
        }
    }

    private var blockedFiles: [DriveFile] {
        selectedSources.compactMap { workspaceStore.file(id: $0) }.filter { file in
            selectedSources.contains(file.id) && !isReadySource(file)
        }
    }

    private var canGenerate: Bool {
        !selectedFiles.isEmpty && blockedFiles.isEmpty
    }

    private var costLabel: String {
        SBGenerationCost.compactEstimate(for: .comparison, sourceCount: selectedFiles.count, quality: qualityTier.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "tablecells",
                        title: "Karşılaştırma Tablosu yükleniyor",
                        message: "Kaynaklar hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar Dene",
                        onAction: { Task { await loadWorkspace() } }
                    )
                } else {
                    headerSection.sbEntrance(0)
                    sourcesPanel.sbEntrance(1)
                    comparisonTypePanel.sbEntrance(2)
                    tableSettingsPanel.sbEntrance(3)
                    generateButton.sbEntrance(4)
                    if !canGenerate {
                        sourceRequiredNotice.sbEntrance(5)
                    }
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground()
        .navigationTitle("Karşılaştırma Tablosu")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "Karşılaştırma",
            title: "Neyi ayıralım?",
            message: "Benzer kavramları kısa tabloya çevir.",
            icon: "tablecells.fill",
            tint: SBColors.cyan
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "book", value: "\(selectedFiles.count)", label: "kaynak", tint: SBColors.green),
                .init(icon: "list.bullet", value: detailLevel.rawValue, label: "yoğunluk", tint: SBColors.purple),
                .init(icon: "target", value: qualityTier.rawValue, label: "kalite", tint: SBColors.orange)
            ])
        }
    }

    // MARK: - Sources Panel

    private var sourcesPanel: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(SBColors.selectedBlue)
                            .frame(width: 40, height: 40)

                        Image(systemName: "doc.text.magnifyingglass")
                            .sbScaledFont(size: 18)
                            .foregroundStyle(SBColors.blue)
                    }

                    Text("Kaynak (\(selectedFiles.count))")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                if selectedFiles.isEmpty {
                    sourceRequiredCard
                } else {
                    ForEach(selectedFiles, id: \.id) { file in
                        sourceLine(file: file)
                    }
                }

                ForEach(blockedFiles, id: \.id) { file in
                    blockedNotice(file: file)
                }

                addSourceButton
            }
        }
    }

    private var sourceRequiredCard: some View {
        SBCard(radius: 14, borderColor: SBColors.blue.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(SBColors.selectedBlue)
                            .frame(width: 40, height: 40)

                        Image(systemName: "doc.text.magnifyingglass")
                            .sbScaledFont(size: 18)
                            .foregroundStyle(SBColors.blue)
                    }

                    Text("Önce bir kaynak seç")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                Text("Hazır bir kaynak seç.")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)

                FlowLayout(spacing: SBSpacing.xs) {
                    tagChip(label: "Hazır kaynak", color: SBColors.blue)
                    tagChip(label: "PDF / PPT(X) / DOC(X)", color: SBColors.purple)
                }
            }
        }
    }

    private func sourceLine(file: DriveFile) -> some View {
        HStack(spacing: SBSpacing.md) {
            SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

            VStack(alignment: .leading, spacing: SBSpacing.xs) {
                Text(file.title)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(2)

                Text("\(file.sizeLabel) • Hazır")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
            }

            Spacer()
        }
        .padding(SBSpacing.sm)
        .background(SBColors.field.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func blockedNotice(file: DriveFile) -> some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .sbScaledFont(size: 16)
                .foregroundStyle(SBColors.orange)

            Text("\(file.title): Hazır değil")
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColors.warningBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var addSourceButton: some View {
        Button {
            router.navigate(to: .sourcePicker)
        } label: {
            HStack(spacing: SBSpacing.md) {
                ZStack {
                    Circle()
                        .fill(SBColors.selectedBlue)
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .sbScaledFont(size: 20, weight: .semibold)
                        .foregroundStyle(SBColors.blue)
                }

                VStack(alignment: .leading, spacing: SBSpacing.xs) {
                    Text("Hazır kaynak ekle")
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.blue)

                    Text("Drive'dan seç.")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressableCardStyle())
    }

    private func tagChip(label: String, color: Color) -> some View {
        Text(label)
            .font(SBTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, SBSpacing.sm)
            .padding(.vertical, SBSpacing.xs)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Comparison Type Panel

    private var comparisonTypePanel: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(SBColors.selectedBlue)
                            .frame(width: 40, height: 40)

                        Image(systemName: "arrow.left.arrow.right")
                            .sbScaledFont(size: 18)
                            .foregroundStyle(SBColors.blue)
                    }

                    Text("Tip")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(ComparisonType.allCases, id: \.self) { type in
                        segmentButton(
                            label: type.rawValue,
                            isSelected: comparisonType == type
                        ) {
                            comparisonType = type
                        }
                    }
                }
            }
        }
    }

    // MARK: - Table Settings Panel

    private var tableSettingsPanel: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                // Table Format
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Format")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                        ForEach(TableFormat.allCases, id: \.self) { format in
                            segmentButton(
                                label: format.rawValue,
                                isSelected: tableFormat == format
                            ) {
                                tableFormat = format
                            }
                        }
                    }
                }

                // Detail Level
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Detay")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                        ForEach(DetailLevel.allCases, id: \.self) { level in
                            segmentButton(
                                label: level.rawValue,
                                isSelected: detailLevel == level
                            ) {
                                detailLevel = level
                            }
                        }
                    }
                }

                // Quality Tier
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Kalite")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                        ForEach(QualityTier.allCases, id: \.self) { tier in
                            segmentButton(
                                label: tier.rawValue,
                                isSelected: qualityTier == tier
                            ) {
                                qualityTier = tier
                            }
                        }
                    }
                }
            }
        }
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(SBTypography.caption)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SBSpacing.md)
                .padding(.horizontal, SBSpacing.sm)
                .background(isSelected ? SBColors.blue : SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? SBColors.blue : SBColors.softLine, lineWidth: 1)
                )
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            canGenerate ? "Tabloyu hazırla • \(costLabel)" : "Kaynak seç",
            icon: canGenerate ? "tablecells" : "folder",
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            fullWidth: true,
            action: {
                if canGenerate {
                    generate()
                } else {
                    router.navigate(to: .sourcePicker)
                }
            }
        )
        .accessibilityLabel(canGenerate ? "Karşılaştırma tablosu oluştur" : "Kaynak seç")
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla tablo üretimini başlatır" : "Kaynak seçme ekranını açar")
    }

    // MARK: - Source Required Notice

    private var sourceRequiredNotice: some View {
        sourceRequiredCard
    }

    // MARK: - Helpers

    private func isReadySource(_ file: DriveFile) -> Bool {
        workspaceStore.isReadyForGeneration(file)
    }

    private func generate() {
        guard let file = selectedFiles.first else {
            workspaceStore.toast("Üretim için önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = [
            comparisonType.rawValue,
            tableFormat.rawValue,
            detailLevel.rawValue,
            qualityTier.rawValue,
            "\(selectedFiles.count) kaynak",
            "mobil tablo"
        ].joined(separator: " • ")
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: file,
                kind: .comparison,
                label: "Karşılaştırma Tablosu",
                surface: "BaseForce Comparison",
                mode: mode,
                extraOptions: [
                    "comparison_type": comparisonType.rawValue,
                    "table_format": tableFormat.rawValue,
                    "detail_level": detailLevel.rawValue,
                    "source_read_policy": "read_full_extracted_document_not_first_excerpt",
                    "source_coverage_policy": "all_selected_sources_all_sections_tables_middle_end_and_conclusions",
                    "source_chunk_policy": "adaptive_full_document_chunk_map_reduce_for_long_sources",
                    "large_source_policy": "10_pages_read_all_200_pages_chunk_index_all_sections_then_synthesize",
                    "ocr_policy": "use_ocr_text_for_scanned_pdf_or_low_text_density_slide_pages_before_generation",
                    "model_router_policy": "route_large_or_sparse_sources_to_long_context_high_reasoning_model",
                    "preferred_model_tier": "latest_premium_high_reasoning_long_context",
                    "model_upgrade_allowed": "true",
                    "minimum_criteria_rows": "8",
                    "comparison_schema": "full_source_matrix_v2",
                    "quality_gate": "reject_first_excerpt_surface_table_or_under_8_criteria_without_source_gap"
                ]
            )
            await MainActor.run {
                isGenerating = false
                if job != nil {
                    SBHaptics.success()
                    router.showGenerationQueue()
                }
            }
        }
    }

    private func loadWorkspace() async {
        isLoading = !workspaceStore.hasLoadedWorkspace
        errorMessage = nil
        await workspaceStore.loadWorkspace()
        errorMessage = workspaceStore.errorMessage
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ComparisonFactoryView()
            .environment(AppState.shared)
    }
}
