import SwiftUI
import SourceBaseBackend

struct AlgorithmFactoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var algorithmMode: AlgorithmMode = .diagnostic
    @State private var algorithmType: AlgorithmType = .pathophysiology
    @State private var flowFormat: FlowFormat = .flowchart
    @State private var outputFormat: OutputFormat = .yesNoBranching
    @State private var detailLevel: DetailLevel = .balanced
    @State private var quality: Quality = .standard
    @State private var colorfulNodes = true
    @State private var clinicalNotes = true

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }

    enum AlgorithmMode: String, CaseIterable {
        case diagnostic = "Tanı"
        case treatment = "Tedavi"
        case clinicalDecision = "Karar"

        var icon: String {
            switch self {
            case .diagnostic: return "arrow.triangle.branch"
            case .treatment: return "waveform.path.ecg"
            case .clinicalDecision: return "point.3.connected.trianglepath.dotted"
            }
        }
    }

    enum AlgorithmType: String, CaseIterable {
        case pathophysiology = "Patofizyoloji"
        case labInterpretation = "Laboratuvar"
        case tusSolving = "TUS çözüm"
        case emergency = "Acil"

        var icon: String {
            switch self {
            case .pathophysiology: return "point.3.connected.trianglepath.dotted"
            case .labInterpretation: return "testtube.2"
            case .tusSolving: return "brain.head.profile"
            case .emergency: return "cross.case"
            }
        }
    }

    enum FlowFormat: String, CaseIterable {
        case flowchart = "Akış şeması"
        case decisionTree = "Karar ağacı"
        case stepwise = "Basamaklı"

        var icon: String {
            switch self {
            case .flowchart: return "arrow.triangle.branch"
            case .decisionTree: return "point.3.connected.trianglepath.dotted"
            case .stepwise: return "list.number"
            }
        }
    }

    enum OutputFormat: String, CaseIterable {
        case yesNoBranching = "Evet/Hayır"
        case mechanismChain = "Mekanizma zinciri"
        case tableFlow = "Tablo + akış"

        var icon: String {
            switch self {
            case .yesNoBranching: return "arrow.triangle.2.circlepath"
            case .mechanismChain: return "link"
            case .tableFlow: return "tablecells"
            }
        }
    }

    enum DetailLevel: String, CaseIterable {
        case brief = "Kısa"
        case balanced = "Dengeli"
        case detailed = "Detaylı"
        case clinical = "Klinik odaklı"
        case exam = "Sınav odaklı"

        var icon: String {
            switch self {
            case .brief: return "slider.horizontal.3"
            case .balanced: return "scope"
            case .detailed: return "list.bullet"
            case .clinical: return "cross.case"
            case .exam: return "graduationcap"
            }
        }
    }

    enum Quality: String, CaseIterable {
        case economy = "Ekonomik"
        case standard = "Standart"
        case premium = "Premium"

        var icon: String {
            switch self {
            case .economy: return "banknote"
            case .standard: return "checkmark.circle"
            case .premium: return "crown"
            }
        }
    }

    private var readySources: [DriveFile] {
        workspaceStore.allFiles.filter { file in
            selectedSources.contains(file.id) && isReadySource(file)
        }
    }

    private var canGenerate: Bool {
        !readySources.isEmpty
    }

    private var sourceSummary: String {
        canGenerate ? "\(readySources.count) kaynak seçildi" : "Kaynak seç"
    }

    private var costLabel: String {
        SBGenerationCost.compactEstimate(for: .algorithm, sourceCount: readySources.count, quality: quality.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseForceFactoryStyle.screenSpacing) {
                if isLoading {
                    SBLoadingState(
                        icon: "arrow.triangle.branch",
                        title: "Algoritma yükleniyor",
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
                    settingsPanel.sbEntrance(2)
                    if quality == .premium {
                        premiumNotice.sbEntrance(3)
                    }
                    togglesSection.sbEntrance(4)
                    generateButton.sbEntrance(5)
                    if !canGenerate {
                        sourceRequiredNotice.sbEntrance(6)
                    }
                }
            }
            .padding(BaseForceFactoryStyle.pagePadding)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle("Akış Şeması")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "Akış",
            title: "Akış şeması üret",
            message: "Süreci karar akışına çevir.",
            icon: "arrow.triangle.branch",
            tint: SBColors.orange,
            size: .compact
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "doc.text.magnifyingglass", value: sourceSummary, label: "kaynak", tint: SBColors.blue),
                .init(icon: flowFormat.icon, value: flowFormat.rawValue, label: "format", tint: SBColors.orange),
                .init(icon: quality.icon, value: quality.rawValue, label: "kalite", tint: SBColors.purple)
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
                    ForEach(Array(selectedSources), id: \.self) { sourceId in
                        if let file = workspaceStore.file(id: sourceId) {
                            sourceChip(file: file)
                        }
                    }

                    addSourceChip
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Önce hazır bir kaynak seç. Alttaki Hazır kaynak seç düğmesini kullan.")
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
    }

    private func sourceChip(file: DriveFile) -> some View {
        HStack(spacing: SBSpacing.xs) {
            SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.title)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)

                Text(file.sizeLabel)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
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

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        BaseForceFactoryStyle.panel(spacing: BaseForceFactoryStyle.settingsSpacing) {
            Text("Ayarlar")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            // Algorithm Mode
            settingsSection(label: "Şablon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(AlgorithmMode.allCases, id: \.self) { mode in
                        segmentButton(
                            label: mode.rawValue,
                            icon: mode.icon,
                            isSelected: algorithmMode == mode
                        ) {
                            algorithmMode = mode
                        }
                    }
                }
            }

            // Algorithm Type
            settingsSection(label: "Tip") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(AlgorithmType.allCases, id: \.self) { type in
                        segmentButton(
                            label: type.rawValue,
                            icon: type.icon,
                            isSelected: algorithmType == type
                        ) {
                            algorithmType = type
                        }
                    }
                }
            }

            // Flow Format
            settingsSection(label: "Biçim") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(FlowFormat.allCases, id: \.self) { format in
                        segmentButton(
                            label: format.rawValue,
                            icon: format.icon,
                            isSelected: flowFormat == format
                        ) {
                            flowFormat = format
                        }
                    }
                }
            }

            // Output Format
            settingsSection(label: "Çıktı") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        segmentButton(
                            label: format.rawValue,
                            icon: format.icon,
                            isSelected: outputFormat == format
                        ) {
                            outputFormat = format
                        }
                    }
                }
            }

            // Detail Level
            settingsSection(label: "Detay") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(DetailLevel.allCases, id: \.self) { level in
                        segmentButton(
                            label: level.rawValue,
                            icon: level.icon,
                            isSelected: detailLevel == level
                        ) {
                            detailLevel = level
                        }
                    }
                }
            }

            // Quality
            settingsSection(label: "Kalite") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(Quality.allCases, id: \.self) { q in
                        segmentButton(
                            label: q.rawValue,
                            icon: q.icon,
                            isSelected: quality == q
                        ) {
                            quality = q
                        }
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text(label)
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.navy)

            content()
        }
    }

    private func segmentButton(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 14)

                Text(label)
                    .font(SBTypography.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? .white : SBColors.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SBSpacing.md)
            .padding(.horizontal, SBSpacing.sm)
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

    // MARK: - Premium Notice

    private var premiumNotice: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "creditcard")
                .sbScaledFont(size: 18)
                .foregroundStyle(SBColors.blue)

            Text("Premium daha fazla MC kullanabilir.")
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColors.selectedBlue)
        .clipShape(RoundedRectangle(cornerRadius: BaseForceFactoryStyle.controlRadius))
    }

    // MARK: - Toggles Section

    private var togglesSection: some View {
        BaseForceFactoryStyle.panel {
            Toggle(isOn: $colorfulNodes) {
                Text("Renkli düğümler")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
            }
            .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))

            Toggle(isOn: $clinicalNotes) {
                Text("Klinik not ekle")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
            }
            .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            "Akışı çiz • \(costLabel)",
            icon: "bolt.fill",
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            isDisabled: !canGenerate,
            fullWidth: true,
            action: generate
        )
        .accessibilityLabel("Klinik algoritma oluştur")
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla akış şeması üretimini başlatır" : "Önce hazır bir kaynak seçmelisin")
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
        guard let file = readySources.first else {
            workspaceStore.toast("Üretim için önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = [
            algorithmMode.rawValue,
            algorithmType.rawValue,
            flowFormat.rawValue,
            outputFormat.rawValue,
            detailLevel.rawValue,
            quality.rawValue,
            colorfulNodes ? "renkli düğüm" : "sade düğüm",
            clinicalNotes ? "klinik notlu" : "klinik notsuz"
        ].joined(separator: " • ")
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: file,
                kind: .algorithm,
                label: "Klinik Algoritma",
                surface: "BaseForce Algorithm",
                mode: mode,
                extraOptions: [
                    "algorithm_type": algorithmType.rawValue,
                    "output_format": outputFormat.rawValue,
                    "detail_level": detailLevel.rawValue
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
        router.beginSourceSelection(from: .baseForce, destination: .route(.algorithmFactory))
    }
}

#Preview {
    NavigationStack {
        AlgorithmFactoryView()
            .environment(AppState.shared)
    }
}
