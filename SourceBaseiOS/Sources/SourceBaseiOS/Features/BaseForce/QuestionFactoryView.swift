import SwiftUI
import SourceBaseBackend

struct QuestionFactoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var questionType: QuestionType = .multipleChoice
    @State private var difficulty: Difficulty = .medium
    @State private var questionCount: Int = 20
    @State private var addExplanation = true
    @State private var quality: SBQualityTier = .standard

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }

    enum QuestionType: String, CaseIterable {
        case multipleChoice = "Test"
        case clinicalCase = "Klinik Vaka"
        case qlinik = "Qlinik"
    }

    enum Difficulty: String, CaseIterable {
        case easy = "Kolay"
        case medium = "Orta"
        case hard = "Zor"
        case veryHard = "Çok Zor"
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
        SBGenerationCost.compactEstimate(for: .question, requestedCount: questionCount, quality: quality.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "questionmark.circle",
                        title: "Soru çözümü yükleniyor",
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
                    generateButton.sbEntrance(3)
                    if !canGenerate {
                        sourceRequiredNotice.sbEntrance(4)
                    }
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle("Soru Çözümü")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "Çözüm pratiği",
            title: "Soru setini hazırla",
            message: "Kaynağı 5 şıklı, açıklamalı sınav pratiğine çevir.",
            icon: "questionmark.circle.fill",
            tint: SBColors.cyan,
            size: .compact
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "doc.text", value: "\(questionCount)", label: "soru", tint: SBColors.cyan),
                .init(icon: "chart.bar.fill", value: difficulty.rawValue, label: "zorluk", tint: SBColors.orange),
                .init(icon: "checkmark.bubble.fill", value: addExplanation ? "Açık" : "Kısa", label: "açıklama", tint: SBColors.green)
            ])
        }
    }

    // MARK: - Selected Sources

    private var selectedSourcesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
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
    }

    private var sourceRequiredCard: some View {
        SBCommandCard(tint: SBColors.cyan, action: {
            openSourcePicker()
        }) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: "doc.text.magnifyingglass", tint: SBColors.cyan, size: 42, radius: 12)

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
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
        SBCard(radius: 16) {
            VStack(spacing: SBSpacing.lg) {
                // Question Type
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    HStack(spacing: SBSpacing.xs) {
                        Image(systemName: "list.bullet")
                            .sbScaledFont(size: 14)
                            .foregroundStyle(SBColors.blue)

                        Text("Tip")
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(SBColors.navy)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                        ForEach(QuestionType.allCases, id: \.self) { type in
                            segmentButton(
                                label: type.rawValue,
                                isSelected: questionType == type
                            ) {
                                questionType = type
                            }
                        }
                    }
                }

                Divider()

                // Difficulty
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    HStack(spacing: SBSpacing.xs) {
                        Image(systemName: "chart.bar")
                            .sbScaledFont(size: 14)
                            .foregroundStyle(SBColors.blue)

                        Text("Zorluk")
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(SBColors.navy)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                        ForEach(Difficulty.allCases, id: \.self) { diff in
                            segmentButton(
                                label: diff.rawValue,
                                isSelected: difficulty == diff
                            ) {
                                difficulty = diff
                            }
                        }
                    }
                }

                Divider()

                // Question Count
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Sayı")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    stepper(value: $questionCount, range: 5...50, step: 5)
                }

                Divider()

                // Explanation Toggle
                Toggle(isOn: $addExplanation) {
                    Text("Açıklama")
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.navy)
                }
                .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))

                SBQualityPicker(selection: $quality)
            }
        }
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(SBTypography.labelSmall)
                .foregroundStyle(isSelected ? .white : SBColors.navy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SBSpacing.md)
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

    private func stepper(value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Button {
                if value.wrappedValue > range.lowerBound {
                    value.wrappedValue -= step
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .sbScaledFont(size: 28)
                    .foregroundStyle(value.wrappedValue > range.lowerBound ? SBColors.blue : SBColors.softLine)
            }
            .disabled(value.wrappedValue <= range.lowerBound)
            .accessibilityLabel("Sayıyı azalt")
            .accessibilityValue("\(value.wrappedValue)")

            Spacer()

            Text("\(value.wrappedValue)")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            Spacer()

            Button {
                if value.wrappedValue < range.upperBound {
                    value.wrappedValue += step
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .sbScaledFont(size: 28)
                    .foregroundStyle(value.wrappedValue < range.upperBound ? SBColors.blue : SBColors.softLine)
            }
            .disabled(value.wrappedValue >= range.upperBound)
            .accessibilityLabel("Sayıyı artır")
            .accessibilityValue("\(value.wrappedValue)")
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            "Soru setini hazırla • \(costLabel)",
            icon: "wand.and.stars",
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            isDisabled: !canGenerate,
            fullWidth: true,
            action: generate
        )
        .accessibilityLabel("Soru seti oluştur")
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla soru üretimini başlatır" : "Önce hazır bir kaynak seçmelisin")
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
            workspaceStore.toast("Üretim için önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = [
            questionType.rawValue,
            difficulty.rawValue,
            "\(questionCount) soru",
            "5 şıklı",
            addExplanation ? "açıklamalı" : "kısa geri bildirimli",
            "Qlinik uyumlu",
            quality.rawValue
        ].joined(separator: " • ")
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: readyFile,
                kind: .question,
                label: "Soru Seti",
                surface: "Üret Soru Çözümü",
                mode: mode,
                extraOptions: [
                    "question_type": questionType.rawValue,
                    "difficulty": difficulty.rawValue,
                    "explanations": String(addExplanation)
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
        router.beginSourceSelection(from: .baseForce, destination: .route(.questionFactory))
    }
}

#Preview {
    NavigationStack {
        QuestionFactoryView()
            .environment(AppState.shared)
    }
}
