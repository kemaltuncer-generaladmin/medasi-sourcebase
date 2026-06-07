import SwiftUI
import SourceBaseBackend

struct SummaryFactoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var summaryLength: SummaryLength = .onePage
    @State private var summaryFocus: SummaryFocus = .highYield
    @State private var markTerms = true
    @State private var toTable = true
    @State private var checklist = true
    @State private var quality: SBQualityTier = .standard

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }

    enum SummaryLength: String, CaseIterable {
        case onePage = "1 sayfa"
        case threePages = "3 sayfa"
        case ultraBrief = "Ultra kısa"
    }

    enum SummaryFocus: String, CaseIterable {
        case highYield = "High-yield"
        case criticalPoints = "Kritikler"
        case teacherEmphasis = "Hoca vurgusu"
    }

    private var readyFile: DriveFile? {
        workspaceStore.allFiles.first { file in
            selectedSources.contains(file.id) && isReadySource(file)
        }
    }

    private var canGenerate: Bool {
        readyFile != nil
    }

    private var costLabel: String {
        SBGenerationCost.compactEstimate(for: .summary, quality: quality.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseForceFactoryStyle.screenSpacing) {
                if isLoading {
                    SBLoadingState(
                        icon: "doc.text",
                        title: "Sınav Sabahı Özeti yükleniyor",
                        message: "Kaynaklar hazırlanıyor..."
                    )
                } else if let error = errorMessage {
                    SBErrorState(
                        title: "Yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadWorkspace() } }
                    )
                } else {
                    headerSection.sbEntrance(0)
                    selectedSourcesSection.sbEntrance(1)
                    settingsGrid.sbEntrance(2)
                    generateButton.sbEntrance(3)
                    if !canGenerate {
                        sourceRequiredNotice.sbEntrance(4)
                    }
                }
            }
            .padding(BaseForceFactoryStyle.pagePadding)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle("Sınav Sabahı Özeti")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "Sınav sabahı",
            title: "Son tekrarı hazırla",
            message: "Yüksek getirili başlıkları, tabloları ve kontrol listesini tek ekrana topla.",
            icon: "doc.text.fill",
            tint: SBColors.purple,
            size: .compact
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "doc.text", value: summaryLength.rawValue, label: "uzunluk", tint: SBColors.purple),
                .init(icon: "target", value: summaryFocus.rawValue, label: "odak", tint: SBColors.blue),
                .init(icon: "square.stack.3d.up", value: readyFile == nil ? "Yok" : "Hazır", label: "kaynak", tint: readyFile == nil ? SBColors.orange : SBColors.green)
            ])
        }
    }

    // MARK: - Selected Sources

    private var selectedSourcesSection: some View {
        BaseForceFactoryStyle.panel {
            Text("Kaynak")
                .font(SBTypography.titleSmall)
                .foregroundStyle(SBColors.navy)

            if selectedSources.isEmpty {
                sourceRequiredCard
            } else {
                FlowLayout(spacing: SBSpacing.sm) {
                    ForEach(Array(selectedSources.prefix(3)), id: \.self) { sourceId in
                        if let file = workspaceStore.file(id: sourceId) {
                            sourceChip(file: file)
                        }
                    }

                    addSourceChip
                }
            }
        }
    }

    private var sourceRequiredCard: some View {
        BaseForceFactoryStyle.sourceRequiredPanel {
            HStack(spacing: SBSpacing.md) {
                SBIconTile(
                    icon: "doc.text.magnifyingglass",
                    tint: SBColors.blue,
                    size: BaseForceFactoryStyle.iconTileSize,
                    radius: BaseForceFactoryStyle.iconTileRadius
                )

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Önce hazır bir kaynak seç. Alttaki Hazır kaynak seç düğmesini kullan.")
    }

    private func sourceChip(file: DriveFile) -> some View {
        HStack(spacing: SBSpacing.xs) {
            SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.title)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)

                Text("\(file.courseTitle) • \(file.sectionTitle) • \(file.sizeLabel)")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, SBSpacing.sm)
        .padding(.vertical, SBSpacing.xs)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: BaseForceFactoryStyle.chipRadius))
        .overlay(
            RoundedRectangle(cornerRadius: BaseForceFactoryStyle.chipRadius)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    private var addSourceChip: some View {
        Button {
            openSourcePicker()
        } label: {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: "plus")
                    .sbScaledFont(size: 14, weight: .semibold)

                Text("Kaynak ekle")
                    .font(SBTypography.caption)
            }
            .foregroundStyle(SBColors.blue)
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: BaseForceFactoryStyle.chipRadius))
            .overlay(
                RoundedRectangle(cornerRadius: BaseForceFactoryStyle.chipRadius)
                    .stroke(SBColors.blue.opacity(0.3), lineWidth: 1.5)
            )
        }
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

    // MARK: - Settings Grid

    private var settingsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240), spacing: BaseForceFactoryStyle.panelSpacing)],
            spacing: BaseForceFactoryStyle.panelSpacing
        ) {
            // Length Panel
            BaseForceFactoryStyle.panel {
                HStack(spacing: SBSpacing.xs) {
                    Image(systemName: "doc.text")
                        .sbScaledFont(size: 14)
                        .foregroundStyle(SBColors.blue)

                    Text("Uzunluk")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                }

                VStack(spacing: SBSpacing.sm) {
                    ForEach(SummaryLength.allCases, id: \.self) { length in
                        segmentButton(
                            label: length.rawValue,
                            isSelected: summaryLength == length
                        ) {
                            summaryLength = length
                        }
                    }
                }
            }

            // Focus Panel
            BaseForceFactoryStyle.panel {
                HStack(spacing: SBSpacing.xs) {
                    Image(systemName: "target")
                        .sbScaledFont(size: 14)
                        .foregroundStyle(SBColors.blue)

                    Text("Odak")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                }

                VStack(spacing: SBSpacing.sm) {
                    ForEach(SummaryFocus.allCases, id: \.self) { focus in
                        segmentButton(
                            label: focus.rawValue,
                            isSelected: summaryFocus == focus
                        ) {
                            summaryFocus = focus
                        }
                    }
                }
            }

            // Highlight Panel
            BaseForceFactoryStyle.panel {
                HStack(spacing: SBSpacing.xs) {
                    Image(systemName: "highlighter")
                        .sbScaledFont(size: 14)
                        .foregroundStyle(SBColors.blue)

                    Text("Ekler")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                }

                VStack(spacing: SBSpacing.sm) {
                    Toggle(isOn: $markTerms) {
                        Text("Terimleri işaretle")
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.navy)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))

                    Toggle(isOn: $toTable) {
                        Text("Tabloya dönüştür")
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.navy)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))

                    Toggle(isOn: $checklist) {
                        Text("Kontrol listesi ekle")
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.navy)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))
                }
            }

            BaseForceFactoryStyle.panel {
                SBQualityPicker(selection: $quality)
            }
        }
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(SBTypography.labelSmall)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SBSpacing.md)
                .background(isSelected ? SBColors.blue : SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: BaseForceFactoryStyle.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: BaseForceFactoryStyle.controlRadius)
                        .stroke(isSelected ? SBColors.blue : SBColors.softLine, lineWidth: 1)
                )
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            "Son tekrarı hazırla • \(costLabel)",
            icon: "bolt.fill",
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            isDisabled: !canGenerate,
            fullWidth: true,
            action: generate
        )
        .accessibilityLabel("Sınav sabahı özeti oluştur")
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla özet üretimini başlatır" : "Önce hazır bir kaynak seçmelisin")
    }

    // MARK: - Source Required Notice

    private var sourceRequiredNotice: some View {
        SBButton(
            "Hazır kaynak seç",
            icon: "folder",
            variant: .secondary,
            size: .medium,
            fullWidth: true,
            action: openSourcePicker
        )
    }

    // MARK: - Helpers

    private func isReadySource(_ file: DriveFile) -> Bool {
        workspaceStore.isReadyForGeneration(file)
    }

    private func generate() {
        guard let readyFile else {
            workspaceStore.toast("Önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = [
            summaryLength.rawValue,
            summaryFocus.rawValue,
            markTerms ? "terim vurgulu" : "terim vurgusuz",
            toTable ? "mini tablolu" : "düz metin",
            checklist ? "kontrol listeli" : "kontrol listesiz",
            quality.rawValue
        ].joined(separator: " • ")
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: readyFile,
                kind: .summary,
                label: "Sınav Sabahı Özeti",
                surface: "Üret Özet",
                mode: mode,
                extraOptions: [
                    "summary_mode": summaryFocus.rawValue,
                    "length_target": summaryLength.rawValue,
                    "output_format": toTable ? "bullet_points+mini_table" : "bullet_points"
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
    private func openSourcePicker() {
        router.beginSourceSelection(from: .baseForce, destination: .route(.summaryFactory))
    }
}

#Preview {
    NavigationStack {
        SummaryFactoryView()
            .environment(AppState.shared)
    }
}
