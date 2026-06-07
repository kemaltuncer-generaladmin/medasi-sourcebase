import SwiftUI
import SourceBaseBackend

struct ClinicalView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var clinicalType: ClinicalType = .tusCase
    @State private var difficulty: Difficulty = .medium
    @State private var level: ClinicalLevel = .singleCase
    @State private var quality: Quality = .standard

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }

    enum ClinicalType: String, CaseIterable {
        case tusCase = "TUS vaka"
        case clinicalDecision = "Karar"
        case emergencyApproach = "Acil"
        case diagnosticCase = "Tanı"
        case treatmentChoice = "Tedavi"
        case basicToClinical = "Temelden kliniğe"
    }

    enum Difficulty: String, CaseIterable {
        case easy = "Kolay"
        case medium = "Orta"
        case hard = "Zor"
        case expert = "Uzman"
    }

    enum ClinicalLevel: String, CaseIterable {
        case singleCase = "Tek vaka"
        case threeShortCases = "3 vaka"
        case questionAnswerCase = "Soru-cevap"
        case explainedCase = "Açıklamalı"
        case stepwiseReasoning = "Adım adım"
    }

    enum Quality: String, CaseIterable {
        case economy = "Ekonomik"
        case standard = "Standart"
        case premium = "Premium"
    }

    private var hasSources: Bool {
        !selectedSources.isEmpty
    }

    private var blockedReasons: [String] {
        selectedSources
            .compactMap { workspaceStore.file(id: $0) }
            .filter { !isReadySource($0) }
            .map { "\($0.title): Hazır değil" }
    }

    private var canGenerate: Bool {
        hasSources && blockedReasons.isEmpty
    }

    private var readySourceCount: Int {
        selectedSources
            .compactMap { workspaceStore.file(id: $0) }
            .filter { isReadySource($0) }
            .count
    }

    private var costLabel: String {
        SBGenerationCost.compactEstimate(for: .clinicalScenario, sourceCount: readySourceCount, quality: quality.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "cross.case",
                        title: "Klinik Senaryo yükleniyor",
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
                    heroSection.sbEntrance(0)
                    step1Sources.sbEntrance(1)
                    step2ClinicalType.sbEntrance(2)
                    step3DifficultyFormat.sbEntrance(3)
                    step4Quality.sbEntrance(4)
                    summaryBar.sbEntrance(5)
                    generateButton.sbEntrance(6)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground()
        .navigationTitle("Klinik Senaryo")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        SBSignatureHero(
            eyebrow: "Klinik akıl yürütme",
            title: "Klinik Senaryo",
            message: "Kaynağı vaka pratiğine çevir.",
            icon: "cross.case.fill",
            tint: SBColors.purple
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "books.vertical", value: "\(selectedSources.count)", label: "kaynak", tint: SBColors.purple),
                .init(icon: "stethoscope", value: clinicalType.rawValue, label: "senaryo", tint: SBColors.orange),
                .init(icon: "chart.bar.fill", value: difficulty.rawValue, label: "zorluk", tint: SBColors.green)
            ])
        }
    }

    // MARK: - Step 1: Sources

    private var step1Sources: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack {
                    stepHeader(number: 1, title: "Kaynak")

                    Spacer()

                    Button {
                        router.navigate(to: .sourcePicker)
                    } label: {
                        HStack(spacing: SBSpacing.xs) {
                            Image(systemName: "folder")
                                .sbScaledFont(size: 14)
                            Text(hasSources ? "Değiştir" : "Seç")
                                .font(SBTypography.labelSmall)
                        }
                        .foregroundStyle(SBColors.blue)
                    }
                    .accessibilityLabel(hasSources ? "Kaynak değiştir" : "Kaynak seç")
                }

                if !hasSources {
                    SBEmptyState(
                        icon: "folder",
                        title: "Kaynak seçilmedi",
                        message: "Hazır bir kaynak seç."
                    )
                } else {
                    FlowLayout(spacing: SBSpacing.sm) {
                        ForEach(Array(selectedSources), id: \.self) { sourceId in
                            if let file = workspaceStore.file(id: sourceId) {
                                sourceChip(file: file)
                            }
                        }
                    }
                }

                ForEach(blockedReasons, id: \.self) { reason in
                    HStack(spacing: SBSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .sbScaledFont(size: 16)
                            .foregroundStyle(SBColors.orange)

                        Text(reason)
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.navy)
                    }
                    .padding(SBSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SBColors.warningBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func sourceChip(file: DriveFile) -> some View {
        HStack(spacing: SBSpacing.xs) {
            SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

            Text(file.title)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)

            Button {
                workspaceStore.setSelectedSources(selectedSources.subtracting([file.id]))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .sbScaledFont(size: 14)
                    .foregroundStyle(SBColors.muted)
            }
            .accessibilityLabel("\(file.title) kaynağını kaldır")
        }
        .padding(.horizontal, SBSpacing.sm)
        .padding(.vertical, SBSpacing.xs)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    // MARK: - Step 2: Clinical Type

    private var step2ClinicalType: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                stepHeader(number: 2, title: "Senaryo")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(ClinicalType.allCases, id: \.self) { type in
                        segmentButton(
                            label: type.rawValue,
                            isSelected: clinicalType == type
                        ) {
                            clinicalType = type
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Difficulty & Format

    private var step3DifficultyFormat: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                stepHeader(number: 3, title: "Zorluk ve biçim")

                // Difficulty
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        segmentButton(
                            label: diff.rawValue,
                            isSelected: difficulty == diff
                        ) {
                            difficulty = diff
                        }
                    }
                }

                // Level
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(ClinicalLevel.allCases, id: \.self) { lvl in
                        segmentButton(
                            label: lvl.rawValue,
                            isSelected: level == lvl
                        ) {
                            level = lvl
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Quality

    private var step4Quality: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                stepHeader(number: 4, title: "Kalite")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(Quality.allCases, id: \.self) { q in
                        segmentButton(
                            label: q.rawValue,
                            isSelected: quality == q
                        ) {
                            quality = q
                        }
                    }
                }

                HStack(spacing: SBSpacing.md) {
                    Image(systemName: "creditcard")
                        .sbScaledFont(size: 16)
                        .foregroundStyle(SBColors.blue)

                    Text("Maliyet: \(SBGenerationCost.label(for: .clinicalScenario, sourceCount: readySourceCount, quality: quality.rawValue)).")
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.muted)
                }
                .padding(SBSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SBColors.selectedBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        SBCard(radius: 14) {
            HStack(spacing: SBSpacing.md) {
                SBIconTile(icon: "doc.text", tint: SBColors.purple, size: 42, radius: 12)

                VStack(alignment: .leading, spacing: SBSpacing.xs) {
                    Text("Özet")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    Text("\(selectedSources.count) kaynak • \(clinicalType.rawValue) • \(difficulty.rawValue) • \(level.rawValue) • \(quality.rawValue)")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            canGenerate ? "Vakayı kur • \(costLabel)" : (hasSources ? "Kaynak hazır değil" : "Kaynak seç"),
            icon: canGenerate ? "cross.case" : (hasSources ? "exclamationmark.triangle" : "folder"),
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            fullWidth: true,
            action: {
                if canGenerate {
                    generate()
                } else if !hasSources {
                    router.navigate(to: .sourcePicker)
                } else {
                    workspaceStore.toast("Seçili kaynak hazır değil.")
                }
            }
        )
        .disabled(isGenerating || (hasSources && !canGenerate))
        .accessibilityLabel(canGenerate ? "Klinik senaryo oluştur" : (hasSources ? "Kaynak hazır değil" : "Kaynak seç"))
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla klinik senaryo üretimini başlatır" : (hasSources ? "Hazır olmayan kaynakla üretim başlatılamaz" : "Kaynak seçme ekranını açar"))
    }

    // MARK: - Helpers

    private func stepHeader(number: Int, title: String) -> some View {
        HStack(spacing: SBSpacing.md) {
            ZStack {
                Circle()
                    .fill(SBColors.purple)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(SBTypography.titleSmall)
                .foregroundStyle(SBColors.navy)
        }
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            SBHaptics.selection()
            action()
        } label: {
            Text(label)
                .font(SBTypography.labelSmall)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SBSpacing.md)
                .padding(.horizontal, SBSpacing.sm)
                .background(isSelected ? SBColors.purple : SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? SBColors.purple : SBColors.softLine, lineWidth: 1)
                )
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    private func isReadySource(_ file: DriveFile) -> Bool {
        workspaceStore.isReadyForGeneration(file)
    }

    private func generate() {
        guard let file = selectedSources
            .compactMap({ workspaceStore.file(id: $0) })
            .first(where: { workspaceStore.isReadyForGeneration($0) }) else {
            workspaceStore.toast("Üretim için önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = "\(clinicalType.rawValue) • \(difficulty.rawValue) • \(level.rawValue) • \(quality.rawValue)"
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: file,
                kind: .clinicalScenario,
                label: "Klinik Senaryo",
                surface: "Derin Çalışma Klinik Senaryo",
                mode: mode,
                extraOptions: [
                    "scenario_type": clinicalType.rawValue,
                    "difficulty": difficulty.rawValue,
                    "output_format": level.rawValue
                ]
            )
            await MainActor.run {
                isGenerating = false
                if job != nil {
                    SBHaptics.success()
                    router.showGenerationQueue(.sourceLab)
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
        ClinicalView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
