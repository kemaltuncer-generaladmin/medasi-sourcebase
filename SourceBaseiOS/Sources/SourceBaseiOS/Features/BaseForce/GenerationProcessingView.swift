import SwiftUI
import SourceBaseBackend

struct GenerationProcessingView: View {
    let sourceFileId: String
    let kindRawValue: String
    let label: String
    let surface: String
    let mode: String
    var extraOptions: [String: String] = [:]

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var currentStep = 0
    @State private var progress = 0.12
    @State private var errorMessage: String?
    @State private var didStart = false
    @State private var isComplete = false

    private var router: AppRouter { appState.router }
    private var kind: GeneratedKind { GeneratedKind(rawValue: kindRawValue) ?? .summary }
    private var sourceFile: DriveFile? { workspaceStore.file(id: sourceFileId) }
    private var contract: SourceBaseGenerationContract {
        SourceBaseGenerationContract.contract(for: kind, mode: mode, source: sourceFile)
    }

    private var steps: [(title: String, detail: String)] {
        let preflight = [
            ("Kaynak kapsamı okunuyor", "Seçili dosya, ders ve bölüm bağlamıyla birlikte değerlendiriliyor."),
            ("Eksik noktalar ayrılıyor", "Kavram boşlukları, çelişkili başlıklar ve sık karıştırılan alanlar işaretleniyor.")
        ]
        switch kind {
        case .flashcard:
            return preflight + [
                ("Kaynak okunuyor", "Kavramlar ve tekrar için uygun cümleler ayrılıyor."),
                ("Kart iskeleti kuruluyor", "Tanım, mekanizma ve klinik ipuçları dengeleniyor."),
                ("Set düzenleniyor", "Kartlar kısa cevap formatında son kontrole alınıyor.")
            ]
        case .question:
            return preflight + [
                ("Kapsam seçiliyor", "Kaynağın soru üretimine uygun bölümleri taranıyor."),
                ("Soru kökleri yazılıyor", "Klinik bağlam ve açıklamalı cevap akışı hazırlanıyor."),
                ("Zorluk dengeleniyor", "Kolaydan zora ilerleyen set son hale getiriliyor.")
            ]
        case .summary:
            return preflight + [
                ("Yüksek getirili noktalar ayrılıyor", "Sınav sabahı okunacak kavramlar öne alınıyor."),
                ("Özet blokları kuruluyor", "Klinik uyarılar ve tekrar maddeleri düzenleniyor."),
                ("Son kontrol yapılıyor", "Kısa, taranabilir çıktı hazırlanıyor.")
            ]
        case .examMorningSummary:
            return preflight + [
                ("Son tekrar hedefi seçiliyor", "Kaynağın sınav sabahına uygun yüksek getirili alanları ayrılıyor."),
                ("Kısa özet kuruluyor", "Mini tablolar, klinik ipuçları ve karıştırılan başlıklar düzenleniyor."),
                ("Okuma akışı netleşiyor", "Çıktı hızlı taranabilir son kontrol listesine çevriliyor.")
            ]
        case .algorithm:
            return preflight + [
                ("Başlangıç noktası bulunuyor", "İlk değerlendirme ve karar girişi çıkarılıyor."),
                ("Akış düğümleri kuruluyor", "Karar adımları mobil dikey akışa ayrılıyor."),
                ("Çıkışlar netleşiyor", "Tedavi, takip ve ileri tetkik seçenekleri düzenleniyor.")
            ]
        case .comparison, .table:
            return preflight + [
                ("Karşılaştırma ekseni seçiliyor", "Konular aynı kriterlerle eşleştiriliyor."),
                ("Ayırt edici alanlar yazılıyor", "Tanı, bulgu ve yaklaşım farkları ayrılıyor."),
                ("Mobil tablo düzenleniyor", "Küçük ekranda okunacak bloklar hazırlanıyor.")
            ]
        case .clinicalScenario:
            return preflight + [
                ("Vaka omurgası kuruluyor", "Hasta özeti, yakınma ve kritik bulgular kaynaktan ayrılıyor."),
                ("Karar noktaları yazılıyor", "Ayırıcı tanı ve klinik akıl yürütme adımları düzenleniyor."),
                ("Geri bildirim ekleniyor", "Açıklamalar ve sık hata uyarıları son kontrole alınıyor.")
            ]
        case .learningPlan:
            return preflight + [
                ("Hedef ve süre ayrılıyor", "Kaynak, uygulanabilir çalışma bloklarına bölünüyor."),
                ("Tekrar aralıkları kuruluyor", "Günlük görevler ve mini sınav noktaları yerleştiriliyor."),
                ("Plan tamamlanıyor", "Son gün kontrol listesi ve tekrar önerileri ekleniyor.")
            ]
        case .podcast:
            return preflight + [
                ("Anlatım hedefi çıkarılıyor", "Konu akışı kısa giriş ve bölümlere ayrılıyor."),
                ("Metin konuşma diline çevriliyor", "Kavramlar doğal anlatım bloklarına bölünüyor."),
                ("Kapanış düzenleniyor", "Son tekrar ve vurgu cümleleri ekleniyor.")
            ]
        case .infographic:
            return preflight + [
                ("Ana mesaj seçiliyor", "Başlık ve tek cümlelik odak belirleniyor."),
                ("Görsel bloklar ayrılıyor", "Bilgi alanları ve kritik notlar düzenleniyor."),
                ("İnfografik tamamlanıyor", "Mobilde okunabilir infografik yapısı hazırlanıyor.")
            ]
        case .mindMap:
            return preflight + [
                ("Merkez kavram bulunuyor", "Kaynağın ana konusu harita merkezine alınıyor."),
                ("Ana dallar kuruluyor", "İlişkili başlıklar kart tabanlı dallara ayrılıyor."),
                ("Bağlantılar ekleniyor", "Karıştırılan noktalar ve klinik ilişkiler bağlanıyor.")
            ]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                hero.sbEntrance(0)
                sourceCard.sbEntrance(1)
                progressCard.sbEntrance(2)
                    .sbCompletionGlow(isComplete, tint: tint(for: kind))

                if let errorMessage {
                    SBErrorState(
                        title: "Üretim tamamlanamadı",
                        message: errorMessage,
                        actionLabel: "Tekrar dene",
                        onAction: { restart() },
                        context: .generation
                    )
                    SBButton("Üretim kuyruğuna dön", icon: "clock", variant: .secondary, size: .medium, fullWidth: true) {
                        router.replaceCurrent(with: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
                    }
                } else if isComplete {
                    SBSuccessState(
                        icon: "checkmark.seal.fill",
                        title: "Üretim başlatıldı",
                        message: "Hazır olur olmaz sonuç ekranına geçebilirsin. İstersen şimdi kuyruktan takip et.",
                        actionLabel: "Kuyruğu gör",
                        onAction: {
                            router.replaceCurrent(with: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
                        },
                        tint: tint(for: kind)
                    )
                } else {
                    SBNotice(
                        icon: "clock.badge.checkmark",
                        message: "Kaynak işleniyor. Sonuç hazır olduğunda kuyrukta ve koleksiyonlarda görebilirsin.",
                        tint: tint(for: kind)
                    )
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .sbPageBackground(tone: .cool)
        .navigationTitle("Üretim")
        .task {
            await startIfNeeded()
        }
    }

    private var hero: some View {
        SBSignatureHero(
            eyebrow: "Üretim",
            title: "\(label) hazırlanıyor",
            message: mode.isEmpty ? "Kaynak adım adım işleniyor." : mode,
            icon: icon(for: kind),
            tint: tint(for: kind)
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "doc.text", value: sourceFile?.kind.rawValue.uppercased() ?? "Kaynak", label: "format", tint: tint(for: kind)),
                .init(icon: "list.bullet.rectangle", value: label, label: "çıktı", tint: SBColors.purple),
                .init(icon: "clock", value: "\(Int(progress * 100))%", label: "ilerleme", tint: SBColors.green)
            ])
        }
    }

    private var sourceCard: some View {
        SBCard(radius: 16) {
            HStack(spacing: SBSpacing.md) {
                SBFileKindBadge(kind: SBFileKind.from(sourceFile?.kind ?? .pdf), compact: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceFile?.title ?? "Drive kaynağı")
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(2)
                    Text(sourceFile.map { "\($0.courseTitle) • \($0.sectionTitle) • \($0.sizeLabel)" } ?? "Kaynak bilgisi yükleniyor")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }

                Spacer()
                SBStatusBadge(status: .processing, compact: true)
            }
        }
    }

    private var progressCard: some View {
        SBCard(radius: 18, borderColor: tint(for: kind).opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                HStack {
                    Spacer()
                    SBProgressRing(progress: progress, tint: tint(for: kind))
                        .padding(.vertical, SBSpacing.sm)
                    Spacer()
                }

                VStack(spacing: SBSpacing.md) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: SBSpacing.md) {
                            Image(systemName: index < currentStep ? "checkmark.circle.fill" : index == currentStep ? "circle.dotted" : "circle")
                                .sbScaledFont(size: 20, weight: .semibold)
                                .foregroundStyle(index <= currentStep ? tint(for: kind) : SBColors.softText)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title)
                                    .font(SBTypography.labelSmall)
                                    .foregroundStyle(SBColors.navy)
                                Text(step.detail)
                                    .font(SBTypography.caption)
                                    .foregroundStyle(SBColors.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(SBSpacing.sm)
                        .background(index == currentStep ? tint(for: kind).opacity(0.08) : SBColors.field)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        await workspaceStore.loadWorkspace()
        await animateSteps()
        await runGeneration()
    }

    private func animateSteps() async {
        for index in steps.indices {
            currentStep = index
            progress = min(0.84, 0.18 + Double(index) * 0.27)
            try? await Task.sleep(nanoseconds: 280_000_000)
        }
    }

    private func runGeneration() async {
        guard let source = workspaceStore.file(id: sourceFileId), workspaceStore.isReadyForGeneration(source) else {
            errorMessage = "Bu kaynak üretim için hazır değil. Hazır bir Drive kaynağı seçip tekrar deneyebilirsin."
            progress = 1
            return
        }

        let job = await workspaceStore.startGeneration(
            file: source,
            kind: kind,
            options: generationOptions
        )

        progress = 1.0
        currentStep = max(steps.count - 1, 0)

        if let job {
            SBHaptics.success()
            await workspaceStore.refreshGenerationQueue()
            withAnimation(SBMotion.softSpring) { isComplete = true }
            try? await Task.sleep(nanoseconds: 500_000_000)
            router.replaceCurrent(with: .result(jobId: job.id))
        } else if let toast = workspaceStore.toastMessage {
            errorMessage = toast
        } else {
            router.replaceCurrent(with: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
        }
    }

    private var generationOptions: [String: String] {
        var options = [
            "label": label,
            "surface": surface,
            "mode": mode,
            "qualityTier": contract.qualityTier,
            "quality_tier": contract.qualityTier,
            "modelPolicy": contract.modelPolicy,
            "model_policy": contract.modelPolicy,
            "preferredModelTier": contract.preferredModelTier,
            "preferred_model_tier": contract.preferredModelTier,
            "modelRouterPolicy": contract.modelRouterPolicy,
            "model_router_policy": contract.modelRouterPolicy,
            "minimumDepth": contract.minimumDepth,
            "minimum_depth": contract.minimumDepth,
            "outputLengthPolicy": contract.outputLengthPolicy,
            "output_length_policy": contract.outputLengthPolicy,
            "sourceReadPolicy": contract.sourceReadPolicy,
            "source_read_policy": contract.sourceReadPolicy,
            "sourceCoveragePolicy": contract.sourceCoveragePolicy,
            "source_coverage_policy": contract.sourceCoveragePolicy,
            "sourceChunkPolicy": contract.sourceChunkPolicy,
            "source_chunk_policy": contract.sourceChunkPolicy,
            "ocrPolicy": "use_ocr_text_for_scanned_or_low_text_density_pages_before_generation",
            "ocr_policy": "use_ocr_text_for_scanned_or_low_text_density_pages_before_generation",
            "largeSourcePolicy": "10_pages_full_read_200_pages_chunk_map_reduce_full_deck_synthesis",
            "large_source_policy": "10_pages_full_read_200_pages_chunk_map_reduce_full_deck_synthesis",
            "qualityGate": contract.qualityGate,
            "quality_gate": contract.qualityGate,
            "modelUpgradeAllowed": "true",
            "model_upgrade_allowed": "true",
            "ecosystemAuditRequired": "true",
            "preflightPolicy": "evaluate_user_ecosystem_mistakes_before_generation",
            "aiBrief": contract.aiBrief,
            "ai_brief": contract.aiBrief,
            "outputContract": contract.outputContract
        ]
        if let imageModelPolicy = contract.imageModelPolicy {
            options["imageModelPolicy"] = imageModelPolicy
            options["image_model_policy"] = imageModelPolicy
            options["gptImageModel"] = imageModelPolicy
            options["gpt_image_model"] = imageModelPolicy
            options["openaiImageModel"] = imageModelPolicy
            options["openai_image_model"] = imageModelPolicy
            options["assetFallbackPolicy"] = "structured_text_blocks_when_image_unavailable"
        }

        if let count = requestedCount {
            options["count"] = String(count)
        }
        if kind == .question {
            options["optionCount"] = "5"
            options["schema"] = "qlinik_public_review_v1"
            options["persistCandidateQuestions"] = "true"
        }
        // Structured per-tool settings (cardStyle, difficulty, scenarioType, ...) so the
        // backend prompt actually honours the student's choices. Contract keys win on collision.
        options.merge(extraOptions) { existing, _ in existing }
        return options
    }

    private var requestedCount: Int? {
        let matches = mode.matches(of: /\d+/)
        return matches.compactMap { Int(String($0.output)) }.last
    }

    private func restart() {
        errorMessage = nil
        progress = 0.12
        currentStep = 0
        didStart = false
        isComplete = false
        Task { await startIfNeeded() }
    }

    private func icon(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard: return "rectangle.on.rectangle"
        case .question: return "questionmark.circle"
        case .summary: return "doc.text"
        case .examMorningSummary: return "alarm"
        case .algorithm: return "arrow.triangle.branch"
        case .comparison, .table: return "tablecells"
        case .clinicalScenario: return "cross.case"
        case .learningPlan: return "calendar.badge.clock"
        case .podcast: return "waveform"
        case .infographic: return "chart.bar.doc.horizontal"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        }
    }

    private func tint(for kind: GeneratedKind) -> Color {
        switch kind {
        case .flashcard: return SBColors.blue
        case .question: return SBColors.cyan
        case .summary: return SBColors.purple
        case .examMorningSummary: return SBColors.purple
        case .algorithm: return SBColors.orange
        case .comparison, .table: return SBColors.blue
        case .clinicalScenario: return SBColors.orange
        case .learningPlan: return SBColors.green
        case .podcast: return SBColors.purple
        case .infographic: return SBColors.cyan
        case .mindMap: return SBColors.purple
        }
    }
}

#Preview {
    NavigationStack {
        GenerationProcessingView(
            sourceFileId: "preview-source",
            kindRawValue: GeneratedKind.flashcard.rawValue,
            label: "Flashcard Seti",
            surface: "BaseForce Flashcard",
            mode: "Dengeli"
        )
        .environment(AppState.shared)
        .environment(SourceBaseWorkspaceStore.shared)
    }
}
