import SwiftUI
import SourceBaseBackend

struct ExamMorningView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var summaryMode: SummaryMode = .examMorningCritical
    @State private var lengthTarget: LengthTarget = .sevenMinutes
    @State private var outputFormats: Set<OutputFormat> = [.bulletPoints, .miniTable]
    @State private var quality: Quality = .standard

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }

    enum SummaryMode: String, CaseIterable {
        case quickReview = "Hızlı"
        case examMorningCritical = "Kritikler"
        case commonlyConfused = "Karıştırılanlar"
        case clinicalTips = "Klinik ipucu"
        case basicScienceMechanism = "Mekanizma"
        case tusHighYield = "TUS"
    }

    enum LengthTarget: String, CaseIterable {
        case threeMinutes = "3 dk"
        case sevenMinutes = "7 dk"
        case fifteenMinutes = "15 dk"
        case detailedFinalReview = "Detaylı"
    }

    enum OutputFormat: String, CaseIterable {
        case bulletPoints = "Madde"
        case miniTable = "Mini tablo"
        case clinicalTipCards = "İpucu kartı"
        case questionAnswer = "Soru-cevap"
        case algorithmicFlow = "Akış"
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
        SBGenerationCost.compactEstimate(for: .examMorningSummary, sourceCount: readySourceCount, quality: quality.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "bolt",
                        title: "Sınav Sabahı yükleniyor",
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
                    heroSection
                    step1Sources
                    step2SummaryMode
                    step3LengthFormat
                    step4Quality
                    generateButton
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground()
        .navigationTitle("Sınav Sabahı")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        SBSignatureHero(
            eyebrow: "Son tekrar",
            title: "Sınav Sabahı",
            message: "Kısa, yüksek verim tekrar.",
            icon: "alarm.fill",
            tint: SBColors.orange
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "books.vertical", value: "\(selectedSources.count)", label: "kaynak", tint: SBColors.orange),
                .init(icon: "timer", value: lengthTarget.rawValue, label: "süre", tint: SBColors.blue),
                .init(icon: "bolt", value: summaryMode.rawValue, label: "mod", tint: SBColors.purple)
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
                        router.beginSourceSelection(from: .baseForce, destination: .route(.examMorning))
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

    // MARK: - Step 2: Summary Mode

    private var step2SummaryMode: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                stepHeader(number: 2, title: "Mod")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(SummaryMode.allCases, id: \.self) { mode in
                        segmentButton(
                            label: mode.rawValue,
                            isSelected: summaryMode == mode
                        ) {
                            summaryMode = mode
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Length & Format

    private var step3LengthFormat: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                stepHeader(number: 3, title: "Süre ve çalışma")

                // Length
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(LengthTarget.allCases, id: \.self) { length in
                        segmentButton(
                            label: length.rawValue,
                            isSelected: lengthTarget == length
                        ) {
                            lengthTarget = length
                        }
                    }
                }

                // Format
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        formatButton(
                            label: format.rawValue,
                            isSelected: outputFormats.contains(format)
                        ) {
                            if outputFormats.contains(format) {
                                if outputFormats.count > 1 {
                                    outputFormats.remove(format)
                                }
                            } else {
                                outputFormats.insert(format)
                            }
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

                    Text("Maliyet: \(SBGenerationCost.label(for: .examMorningSummary, sourceCount: readySourceCount, quality: quality.rawValue)).")
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

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            canGenerate ? "Son tekrarı hazırla • \(costLabel)" : (hasSources ? "Kaynak hazır değil" : "Kaynak seç"),
            icon: canGenerate ? "alarm" : (hasSources ? "exclamationmark.triangle" : "folder"),
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            fullWidth: true,
            action: {
                if canGenerate {
                    generate()
                } else if !hasSources {
                    router.beginSourceSelection(from: .baseForce, destination: .route(.examMorning))
                } else {
                    workspaceStore.toast("Seçili kaynak hazır değil.")
                }
            }
        )
        .disabled(isGenerating || (hasSources && !canGenerate))
        .accessibilityLabel(canGenerate ? "Sınav sabahı özeti oluştur" : (hasSources ? "Kaynak hazır değil" : "Kaynak seç"))
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla sınav sabahı üretimini başlatır" : (hasSources ? "Hazır olmayan kaynakla üretim başlatılamaz" : "Kaynak seçme ekranını açar"))
    }

    // MARK: - Helpers

    private func stepHeader(number: Int, title: String) -> some View {
        HStack(spacing: SBSpacing.md) {
            ZStack {
                Circle()
                    .fill(SBColors.blue)
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
        Button(action: action) {
            Text(label)
                .font(SBTypography.labelSmall)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
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

    private func formatButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .sbScaledFont(size: 12, weight: .bold)
                }

                Text(label)
                    .font(SBTypography.caption)
                    .lineLimit(2)
            }
            .foregroundStyle(isSelected ? SBColors.blue : SBColors.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SBSpacing.md)
            .padding(.horizontal, SBSpacing.sm)
            .background(isSelected ? SBColors.selectedBlue : SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? SBColors.blue : SBColors.softLine, lineWidth: 1)
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
            workspaceStore.toast("Önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = "\(summaryMode.rawValue) • \(lengthTarget.rawValue) • \(quality.rawValue)"
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: file,
                kind: .examMorningSummary,
                label: "Sınav Sabahı Özeti",
                surface: "Derin Çalışma Sınav Sabahı",
                mode: mode,
                extraOptions: [
                    "summary_mode": summaryMode.rawValue,
                    "length_target": lengthTarget.rawValue,
                    "output_format": outputFormats.map(\.rawValue).sorted().joined(separator: "+")
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
        ExamMorningView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
