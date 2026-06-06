import SwiftUI
import SourceBaseBackend

struct FlashcardFactoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false

    // Settings
    @State private var cardStyle: CardStyle = .classic
    @State private var cardCount: Int = 10
    @State private var difficulty: Difficulty = .medium
    @State private var extractKeyConcepts = true
    @State private var addHints = true

    private var router: AppRouter { appState.router }
    private var selectedSources: Set<String> { workspaceStore.selectedSourceIds }
    private let allowedCardCounts = [5, 10, 15, 20, 25]

    enum CardStyle: String, CaseIterable {
        case classic = "Klasik"
        case cloze = "Cloze"
        case rapidReview = "Hızlı"

        var icon: String {
            switch self {
            case .classic: return "rectangle.on.rectangle"
            case .cloze: return "ellipsis"
            case .rapidReview: return "arrow.triangle.2.circlepath"
            }
        }

        /// Canonical token the backend prompt branches on.
        var backendValue: String {
            switch self {
            case .classic: return "classic"
            case .cloze: return "cloze"
            case .rapidReview: return "rapid_review"
            }
        }
    }

    enum Difficulty: String, CaseIterable {
        case easy = "Kolay"
        case medium = "Orta"
        case hard = "Zor"

        var color: Color {
            switch self {
            case .easy: return SBColors.green
            case .medium: return SBColors.orange
            case .hard: return SBColors.red
            }
        }
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
        SBGenerationCost.compactEstimate(for: .flashcard, requestedCount: cardCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "rectangle.on.rectangle",
                        title: "Flashcard çalışması yükleniyor",
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
        .sbPageBackground()
        .navigationTitle("Flashcard")
        .task {
            await loadWorkspace()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "Aktif hatırlama",
            title: "Ezber kartlarını hazırla",
            message: "Tanım, mekanizma ve sık karıştırılan noktaları kısa karta çevir.",
            icon: "rectangle.on.rectangle",
            tint: SBColors.blue
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "rectangle.on.rectangle", value: "\(cardCount)", label: "kart", tint: SBColors.blue),
                .init(icon: "chart.bar.fill", value: difficulty.rawValue, label: "zorluk", tint: difficulty.color),
                .init(icon: "doc.text", value: readyFile == nil ? "Yok" : "Hazır", label: "kaynak", tint: readyFile == nil ? SBColors.orange : SBColors.green)
            ])
        }
    }

    // MARK: - Sources Panel

    private var sourcesPanel: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: "doc.text", tint: SBColors.blue, size: 42, radius: 12)

                    Text("Kaynak")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                if selectedSources.isEmpty {
                    sourceRequiredCard
                } else {
                    ForEach(Array(selectedSources), id: \.self) { sourceId in
                        if let file = workspaceStore.file(id: sourceId) {
                            selectedSourceCard(file: file)
                        }
                    }
                }

                addSourceButton
            }
        }
    }

    private var sourceRequiredCard: some View {
        SBCommandCard(tint: SBColors.blue, action: {
            router.navigate(to: .sourcePicker)
        }) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: "doc.text.magnifyingglass", tint: SBColors.blue, size: 42, radius: 12)

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

    private func selectedSourceCard(file: DriveFile) -> some View {
        SBCard(radius: 14) {
            HStack(spacing: SBSpacing.md) {
                SBFileKindBadge(kind: SBFileKind.from(file.kind), compact: true)

                VStack(alignment: .leading, spacing: SBSpacing.xs) {
                    Text(file.title)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(file.courseTitle) • \(file.sectionTitle) • \(file.sizeLabel)")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    router.navigate(to: .sourcePicker)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .sbScaledFont(size: 18)
                        .foregroundStyle(SBColors.muted)
                }
                .accessibilityLabel("Kaynak değiştir")
            }
        }
    }

    private var addSourceButton: some View {
        SBCommandCard(tint: SBColors.blue, action: {
            router.navigate(to: .sourcePicker)
        }) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: "plus", tint: SBColors.blue, size: 44, radius: 13)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text("Hazır kaynak ekle")
                            .font(SBTypography.labelMedium)
                            .foregroundStyle(SBColors.blue)

                        Text("Drive'dan seç.")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                }
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: "slider.horizontal.3", tint: SBColors.blue, size: 42, radius: 12)

                    Text("Ayarlar")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                // Card Style
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Stil")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    HStack(spacing: SBSpacing.sm) {
                        ForEach(CardStyle.allCases, id: \.self) { style in
                            segmentButton(
                                label: style.rawValue,
                                icon: style.icon,
                                isSelected: cardStyle == style
                            ) {
                                cardStyle = style
                            }
                        }
                    }
                }

                // Card Count
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Sayı")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                        ForEach(allowedCardCounts, id: \.self) { count in
                            Button {
                                cardCount = count
                            } label: {
                                Text("\(count)")
                                    .font(SBTypography.labelSmall)
                                    .foregroundStyle(cardCount == count ? .white : SBColors.navy)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SBSpacing.sm)
                                    .background(cardCount == count ? SBColors.blue : SBColors.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(cardCount == count ? SBColors.blue : SBColors.softLine, lineWidth: 1)
                                    )
                            }
                            .accessibilityLabel("\(count) kart")
                            .accessibilityValue(cardCount == count ? "Seçili" : "Seçili değil")
                        }
                    }
                }

                // Difficulty
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Zorluk")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)

                    HStack(spacing: SBSpacing.sm) {
                        ForEach(Difficulty.allCases, id: \.self) { diff in
                            difficultyChip(
                                label: diff.rawValue,
                                color: diff.color,
                                isSelected: difficulty == diff
                            ) {
                                difficulty = diff
                            }
                        }
                    }
                }

                // Toggles
                VStack(spacing: SBSpacing.sm) {
                    toggleRow(label: "Kavram çıkar", isOn: $extractKeyConcepts)
                    toggleRow(label: "İpucu ekle", isOn: $addHints)
                }
            }
        }
    }

    private func segmentButton(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 18)

                Text(label)
                    .font(SBTypography.caption)
            }
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

    private func difficultyChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(SBTypography.labelSmall)
                .foregroundStyle(isSelected ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SBSpacing.sm)
                .background(isSelected ? color : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: 1.5)
                )
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
        }
        .toggleStyle(SwitchToggleStyle(tint: SBColors.blue))
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

    // MARK: - Generate Button

    private var generateButton: some View {
        SBButton(
            canGenerate ? "Kartları hazırla • \(costLabel)" : "Kaynak seç",
            icon: canGenerate ? "bolt.fill" : "folder",
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
        .accessibilityLabel(canGenerate ? "Flashcard seti oluştur" : "Kaynak seç")
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla flashcard üretimini başlatır" : "Kaynak seçme ekranını açar")
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
        guard let readyFile else {
            workspaceStore.toast("Üretim için önce hazır bir kaynak seç.")
            return
        }
        isGenerating = true
        let mode = [
            cardStyle.rawValue,
            difficulty.rawValue,
            "\(cardCount) kart",
            extractKeyConcepts ? "önemli kavram çıkar" : "tüm kapsamdan seç",
            addHints ? "ipucu ekle" : "ipucu ekleme"
        ].joined(separator: " • ")
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: readyFile,
                kind: .flashcard,
                label: "Flashcard Seti",
                surface: "BaseForce Flashcard",
                mode: mode,
                extraOptions: [
                    "card_style": cardStyle.backendValue,
                    "difficulty": difficulty.rawValue,
                    "extract_key_concepts": String(extractKeyConcepts),
                    "add_hints": String(addHints)
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
        FlashcardFactoryView()
            .environment(AppState.shared)
    }
}
