import SwiftUI
import SourceBaseBackend

struct SourceLabToolFlowView: View {
    let title: String
    let subtitle: String
    let kind: GeneratedKind
    let outputLabel: String
    let icon: String
    let tint: Color
    let controls: [String]
    let previewSections: [String]

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGenerating = false
    @State private var selectedControl: String
    @State private var selectedQuality: SBQualityTier = .standard

    init(
        title: String,
        subtitle: String,
        kind: GeneratedKind,
        outputLabel: String,
        icon: String,
        tint: Color,
        controls: [String],
        previewSections: [String]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.outputLabel = outputLabel
        self.icon = icon
        self.tint = tint
        self.controls = controls
        self.previewSections = previewSections
        _selectedControl = State(initialValue: controls.first ?? "Dengeli")
    }

    private var router: AppRouter { appState.router }
    private var readyFile: DriveFile? { workspaceStore.selectedReadyFiles.first }
    private var canGenerate: Bool { readyFile != nil }
    private var isInfographic: Bool { kind == .infographic }
    private var costLabel: String {
        SBGenerationCost.compactEstimate(for: kind, quality: selectedQuality.rawValue)
    }

    private func infographicImageModel(for quality: SBQualityTier) -> String {
        switch quality {
        case .economy: return "gpt-image-1-mini"
        case .standard: return "gpt-image-1.5"
        case .premium: return "gpt-image-2"
        }
    }

    private func infographicImageQuality(for quality: SBQualityTier) -> String {
        switch quality {
        case .economy: return "low"
        case .standard: return "standard"
        case .premium: return "premium"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(icon: icon, title: "\(title) yükleniyor", message: "Kaynaklar hazırlanıyor...")
                } else if let errorMessage {
                    SBErrorState(title: "Yüklenemedi", message: errorMessage, actionLabel: "Tekrar dene") {
                        Task { await loadWorkspace() }
                    }
                } else {
                    hero.sbEntrance(0)
                    sourceCard.sbEntrance(1)
                    controlsCard.sbEntrance(2)
                    qualityCard.sbEntrance(3)
                    previewCard.sbEntrance(4)
                    generateButton.sbEntrance(5)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(760)
        }
        .sbPageBackground()
        .navigationTitle(title)
        .sbInlineNavTitle()
        .task {
            await loadWorkspace()
        }
    }

    private var hero: some View {
        SBSignatureHero(
            eyebrow: "Derin çalışma",
            title: title,
            message: subtitle,
            icon: icon,
            tint: tint
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "doc.text", value: readyFile == nil ? "Yok" : "Hazır", label: "kaynak", tint: readyFile == nil ? SBColors.orange : SBColors.green),
                .init(icon: "slider.horizontal.3", value: selectedControl, label: "odak", tint: tint),
                .init(icon: "creditcard", value: costLabel, label: "tahmin", tint: SBColors.orange)
            ])
        }
    }

    private var sourceCard: some View {
        SBCard(radius: 16, borderColor: tint.opacity(0.16)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack {
                    Text("Kaynak")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                    Spacer()
                    Button("Değiştir") {
                        router.navigate(to: .sourcePicker)
                    }
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.blue)
                    .accessibilityLabel("Kaynak değiştir")
                }

                if let readyFile {
                    HStack(spacing: SBSpacing.md) {
                        SBFileKindBadge(kind: SBFileKind.from(readyFile.kind), compact: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(readyFile.title)
                                .font(SBTypography.labelMedium)
                                .foregroundStyle(SBColors.navy)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(readyFile.courseTitle) • \(readyFile.sectionTitle) • \(readyFile.sizeLabel)")
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.muted)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        SBStatusBadge(status: .ready, compact: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Seçili kaynak: \(readyFile.title)")
                    .accessibilityValue("\(readyFile.courseTitle), \(readyFile.sectionTitle), \(readyFile.sizeLabel), hazır")
                } else {
                    SBEmptyState(
                        icon: "folder.badge.plus",
                        title: "Hazır kaynak seç",
                        message: "Üretime başlamadan önce kullanacağın hazır kaynağı seç.",
                        actionLabel: "Kaynak seç",
                        onAction: { router.navigate(to: .sourcePicker) }
                    )
                }
            }
        }
    }

    private var controlsCard: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    SBIconTile(icon: "slider.horizontal.3", tint: tint, size: 38, radius: 11)
                    Text("Çalışma odağı")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                FlowLayout(spacing: SBSpacing.sm) {
                    ForEach(controls, id: \.self) { control in
                        Button {
                            SBHaptics.selection()
                            selectedControl = control
                        } label: {
                            Text(control)
                                .font(SBTypography.labelSmall)
                                .foregroundStyle(selectedControl == control ? .white : SBColors.navy)
                                .padding(.horizontal, SBSpacing.md)
                                .padding(.vertical, SBSpacing.sm)
                                .background(selectedControl == control ? tint : SBColors.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selectedControl == control ? tint : SBColors.softLine, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(control)
                        .accessibilityValue(selectedControl == control ? "Seçili" : "Seçili değil")
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    SBIconTile(icon: "list.bullet.rectangle", tint: tint, size: 38, radius: 11)
                    Text("Çalışma ekranında")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                }

                VStack(spacing: SBSpacing.sm) {
                    ForEach(Array(previewSections.enumerated()), id: \.offset) { index, section in
                        HStack(spacing: SBSpacing.md) {
                            Text("\(index + 1)")
                                .font(SBTypography.labelSmall)
                                .foregroundStyle(tint)
                                .frame(width: 28, height: 28)
                                .background(tint.opacity(0.12))
                                .clipShape(Circle())

                            Text(section)
                                .font(SBTypography.bodySmall)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()
                        }
                        .padding(SBSpacing.sm)
                        .background(SBColors.field)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(index + 1). çıktı bölümü")
                        .accessibilityValue(section)
                    }
                }
            }
        }
    }

    private var qualityCard: some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    SBIconTile(icon: "sparkles", tint: tint, size: 38, radius: 11)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kalite")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Text(isInfographic ? infographicImageModel(for: selectedQuality) : selectedQuality.subtitle)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                    Spacer()
                    Text(costLabel)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.orange)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(SBQualityTier.allCases, id: \.self) { quality in
                        qualityButton(quality)
                    }
                }
            }
        }
    }

    private func qualityButton(_ quality: SBQualityTier) -> some View {
        Button {
            SBHaptics.selection()
            selectedQuality = quality
        } label: {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: quality.icon)
                    .sbScaledFont(size: 14, weight: .semibold)

                Text(quality.rawValue)
                    .font(SBTypography.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(selectedQuality == quality ? .white : SBColors.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SBSpacing.md)
            .padding(.horizontal, SBSpacing.sm)
            .background(selectedQuality == quality ? tint : SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedQuality == quality ? tint : SBColors.softLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(quality.rawValue) kalite")
        .accessibilityValue(selectedQuality == quality ? "Seçili" : "Seçili değil")
        .accessibilityHint(quality.subtitle)
    }

    private var generateButton: some View {
        SBButton(
            canGenerate ? (isGenerating ? "Hazırlanıyor..." : "\(outputLabel) hazırla • \(costLabel)") : "Kaynak seç",
            icon: canGenerate ? "wand.and.stars" : "folder",
            variant: .primary,
            size: .large,
            isLoading: isGenerating,
            fullWidth: true
        ) {
            if canGenerate {
                generate()
            } else {
                router.navigate(to: .sourcePicker)
            }
        }
        .disabled(isGenerating)
        .accessibilityLabel(canGenerate ? "\(outputLabel) oluştur" : "Kaynak seç")
        .accessibilityHint(canGenerate ? "Seçili hazır kaynakla üretimi başlatır" : "Hazır kaynak seçme ekranını açar")
    }

    private func generate() {
        guard let readyFile else {
            workspaceStore.toast("Üretim için önce hazır bir kaynak seç.")
            return
        }
        let controlKey: String
        switch kind {
        case .mindMap: controlKey = "map_type"
        case .learningPlan: controlKey = "daily_time"
        case .infographic: controlKey = "infographic_type"
        default: controlKey = "detail_level"
        }
        let mode = "\(selectedControl) • \(selectedQuality.rawValue)"
        var options = [controlKey: selectedControl]
        options["qualityTier"] = selectedQuality.tier
        options["quality_tier"] = selectedQuality.tier
        if kind == .infographic {
            let imageModel = infographicImageModel(for: selectedQuality)
            let imageQuality = infographicImageQuality(for: selectedQuality)
            options["imageModelPolicy"] = imageModel
            options["image_model_policy"] = imageModel
            options["gptImageModel"] = imageModel
            options["gpt_image_model"] = imageModel
            options["openaiImageModel"] = imageModel
            options["openai_image_model"] = imageModel
            options["imageQuality"] = imageQuality
            options["image_quality"] = imageQuality
            options["visual_layout"] = selectedControl == "Kare" ? "Kare" : "Dikey"
            options["visual_density"] = selectedControl == "Sade" ? "Sade" : selectedControl == "Yoğun" ? "Yoğun" : "Dengeli"
            options["learning_focus"] = infographicLearningFocus(for: selectedControl)
            options["assetFallbackPolicy"] = "structured_text_blocks_when_image_unavailable"
            options["shareableAssetPolicy"] = "remote_image_url_or_renderable_text"
            options["visualAssetRequired"] = "true"
            options["visualOutputContract"] = "image_url_plus_structured_sections"
            options["visualReadabilityPolicy"] = "large_clear_labels_mobile_readable_no_tiny_text"
            options["medicalInfographicPolicy"] = "clinically_grounded_main_message_red_flags_quick_check_source_note"
            options["imagePromptPolicy"] = "vivid_medical_student_infographic_not_stock_photo"
            options["assetFormat"] = "png_or_jpg_shareable"
        }
        if kind == .podcast {
            options["voice_style"] = selectedControl
            options["audioAssetRequired"] = "true"
            options["audioFormat"] = "m4a_or_mp3_exportable"
            options["podcastOutputContract"] = "audio_url_plus_full_segment_transcript"
        }
        isGenerating = true
        Task {
            let job = await workspaceStore.enqueueGeneration(
                file: readyFile,
                kind: kind,
                label: outputLabel,
                surface: "Derin Çalışma \(outputLabel)",
                mode: mode,
                extraOptions: options
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

    private func infographicLearningFocus(for control: String) -> String {
        switch control {
        case "Klinik":
            return "clinical_red_flags_and_decision_cues"
        case "Sınav":
            return "exam_high_yield_active_recall"
        case "Yoğun":
            return "dense_comprehensive_visual_review"
        case "Sade":
            return "simple_first_pass_visual_memory"
        case "Kare":
            return "shareable_square_visual_summary"
        case "Dikey":
            return "mobile_vertical_visual_study"
        default:
            return "medical_student_visual_study"
        }
    }
}
