import Foundation
import Testing
import SourceBaseBackend
@testable import SourceBaseiOS

@Test func pickedDriveFileAcceptsReleaseDocumentTypes() async throws {
    let files = [
        ("lecture.pdf", "application/pdf"),
        ("slides.pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"),
        ("notes.docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        ("legacy.ppt", "application/vnd.ms-powerpoint"),
        ("legacy.doc", "application/msword")
    ]

    for (name, contentType) in files {
        let file = PickedDriveFile(
            name: name,
            contentType: contentType,
            sizeBytes: 3,
            data: Data([1, 2, 3])
        )
        #expect(file.hasSupportedExtension)
        #expect(file.hasReadableContent)
    }
}

@Test func generatedOutputKeepsBackendContentText() async throws {
    let output = GeneratedOutput(
        id: "output-1",
        sourceFileId: "file-1",
        kind: .summary,
        rawType: "summary",
        title: "Özet",
        detail: "2 öğe",
        contentText: "Başlık\n- Birinci madde\n- İkinci madde",
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 2,
        jobId: "job-1"
    )

    #expect(output.contentText?.contains("Birinci madde") == true)
    #expect(output.isReady)
}

@Test func generationContractDefaultsToPremiumQuality() async throws {
    let contract = SourceBaseGenerationContract.contract(
        for: .summary,
        mode: "standart özet",
        source: nil
    )

    #expect(contract.qualityTier == "standard")
    #expect(contract.modelPolicy == "premium_balanced_long_context_summary_synthesis_first")
    #expect(contract.minimumDepth == "premium_balanced_deep")
    #expect(contract.outputLengthPolicy == "balanced_comprehensive_structured_not_short")
    #expect(contract.sourceReadPolicy == "read_full_extracted_document_not_first_excerpt")
    #expect(contract.sourceChunkPolicy.contains("chunk_map_reduce"))
    #expect(contract.modelRouterPolicy.contains("long_context"))
    #expect(contract.preferredModelTier == "latest_premium_balanced_long_context")
    #expect(contract.aiBrief.contains("premium"))
    #expect(contract.aiBrief.contains("200 sayfalık"))
    #expect(contract.aiBrief.contains("Study workspace"))
    #expect(contract.outputContract.contains("tek kısa paragraf olmamalı"))
    #expect(contract.outputContract.contains("mini_table"))
    #expect(contract.outputContract.contains("self_check"))
    #expect(contract.learningSciencePolicy.contains("retrieval_practice"))
    #expect(contract.retrievalPracticePolicy == "force_commit_before_answer_with_self_check_or_questions")
    #expect(contract.spacedReviewPolicy.contains("24h"))
    #expect(contract.studentOutcomeContract.contains("review_later"))
    #expect(contract.aiBrief.contains("aktif hatırlama"))
    #expect(contract.aiBrief.contains("spaced review"))
}

@Test func comparisonContractRequiresFullSourceMatrix() async throws {
    let contract = SourceBaseGenerationContract.contract(
        for: .comparison,
        mode: "klinik tablo",
        source: nil
    )

    #expect(contract.modelPolicy == "premium_latest_long_context_matrix_reasoning_first")
    #expect(contract.minimumDepth == "full_source_matrix_deep")
    #expect(contract.preferredModelTier == "latest_premium_high_reasoning_long_context")
    #expect(contract.outputContract.contains("source_coverage"))
    #expect(contract.outputContract.contains("source_refs"))
    #expect(contract.outputContract.contains("En az 8"))
    #expect(contract.qualityGate.contains("under_8_criteria"))
}

@Test func generatedOutputBuildsLayeredStudyWorkspaceBlocks() async throws {
    let output = GeneratedOutput(
        id: "output-layered-summary",
        sourceFileId: "file-1",
        kind: .summary,
        rawType: "summary",
        title: "Kardiyoloji Çalışma Alanı",
        detail: "Katmanlı çıktı",
        content: .object([
            "summary": .string("Kalp yetmezliği çıktısı kaynak odaklı çalışma paketidir."),
            "high_yield_points": .array([
                .string("EF düşüklüğü sınıflandırmayı değiştirir."),
                .string("Konjesyon tedavi önceliğini belirler.")
            ]),
            "mini_table": .object([
                "headers": .array([.string("Bulgu"), .string("Anlam"), .string("Eylem")]),
                "rows": .array([
                    .object([
                        "Bulgu": .string("Ortopne"),
                        "Anlam": .string("Konjesyon"),
                        "Eylem": .string("Volüm değerlendirmesi")
                    ])
                ])
            ]),
            "clinicalDecisionFlow": .array([
                .string("Dispne varsa konjesyon bulgularını değerlendir."),
                .string("Hipotansiyon varsa acil yaklaşım planla.")
            ]),
            "self_check": .array([
                .object([
                    "question": .string("EF neden sınıflandırmada önemlidir?"),
                    "answer": .string("Tedavi ve risk grubunu değiştirir."),
                    "explanation": .string("Kaynakta EF temelli ayrım vurgulanır.")
                ])
            ]),
            "next_review_prompts": .array([
                .string("24 saat sonra EF sınıflarını kapalı notla tekrar et.")
            ]),
            "source_gaps": .array([.string("Kaynakta BNP eşikleri net verilmemiş.")])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 5,
        jobId: "job-layered"
    )

    let document = output.studyDocument
    #expect(document.summary.contains("Kalp yetmezliği"))
    #expect(document.blocks.contains { if case .calloutList(_, "Yüksek Verimli Noktalar", _, .mustKnow) = $0 { return true }; return false })
    #expect(document.blocks.contains { if case .table(_, "Mini Tablo", let table) = $0 { return table.headers.count == 3 && table.rows.count == 1 }; return false })
    #expect(document.blocks.contains { if case .steps(_, "Klinik Karar Akışı", let items) = $0 { return items.count == 2 }; return false })
    #expect(document.blocks.contains { if case .qa(_, "Kendini Kontrol Et", let pairs) = $0 { return pairs.first?.answer.contains("Tedavi") == true }; return false })
    #expect(document.blocks.contains { if case .calloutList(_, "Sonraki Tekrar", let items, .objective) = $0 { return items.first?.contains("24 saat") == true }; return false })
    #expect(document.blocks.contains { if case .calloutList(_, "Kaynakta Eksik Kalanlar", _, .redFlag) = $0 { return true }; return false })
}

@Test func generationContractKeepsAllQualityChoicesPremiumGrounded() async throws {
    let flashcards = SourceBaseGenerationContract.contract(
        for: .flashcard,
        mode: "ekonomik tekrar",
        source: nil
    )
    let questions = SourceBaseGenerationContract.contract(
        for: .question,
        mode: "ekonomik soru",
        source: nil
    )

    #expect(flashcards.qualityTier == "economy")
    #expect(flashcards.modelPolicy == "premium_efficient_long_context_active_recall_quality_first")
    #expect(flashcards.outputLengthPolicy == "complete_set_compact_explanations_not_short")
    #expect(flashcards.preferredModelTier == "latest_premium_efficient_long_context")
    #expect(questions.qualityTier == "economy")
    #expect(questions.modelPolicy == "premium_efficient_long_context_assessment_quality_first")
    #expect(questions.sourceReadPolicy == "read_full_extracted_document_not_first_excerpt")
}

@Test func infographicGenerationContractMapsQualityToGptImageModels() async throws {
    let economy = SourceBaseGenerationContract.contract(
        for: .infographic,
        mode: "ekonomik klinik",
        source: nil
    )
    let standard = SourceBaseGenerationContract.contract(
        for: .infographic,
        mode: "standart klinik",
        source: nil
    )
    let premium = SourceBaseGenerationContract.contract(
        for: .infographic,
        mode: "premium klinik",
        source: nil
    )

    #expect(economy.qualityTier == "economy")
    #expect(economy.imageModelPolicy == "gpt-image-1-mini")
    #expect(standard.qualityTier == "standard")
    #expect(standard.imageModelPolicy == "gpt-image-1.5")
    #expect(premium.qualityTier == "premium")
    #expect(premium.imageModelPolicy == "gpt-image-2")
}

@Test func generationJobPhaseAcceptsBackendStatusVariants() async throws {
    #expect(GenerationJobPhase(rawStatus: "done") == .completed)
    #expect(GenerationJobPhase(rawStatus: "finished") == .completed)
    #expect(GenerationJobPhase(rawStatus: "in-progress") == .running)
    #expect(GenerationJobPhase(rawStatus: "pending") == .queued)
    #expect(GenerationJobPhase(rawStatus: "cancelled") == .failed)
}

@Test func generatedOutputTreatsFinishedStatusesAsReady() async throws {
    let output = GeneratedOutput(
        id: "output-finished",
        sourceFileId: "file-1",
        kind: .summary,
        rawType: "summary",
        title: "Özet",
        detail: "Hazır",
        updatedLabel: "Bugün",
        status: "finished",
        itemCount: 1,
        jobId: "job-finished"
    )

    #expect(output.isReady)
}

@Test func legalLinksAreValidHTTPS() async throws {
    #expect(SBLegalLinks.privacyURL.scheme == "https")
    #expect(SBLegalLinks.termsURL.scheme == "https")
    #expect(SBLegalLinks.privacyURL.host()?.contains("sourcebase") == true)
    #expect(SBLegalLinks.termsURL.host()?.contains("sourcebase") == true)
}

@Test func studyExportTextIncludesTemplateSections() async throws {
    let output = GeneratedOutput(
        id: "output-export",
        sourceFileId: "file-1",
        kind: .examMorningSummary,
        rawType: "exam_morning_summary",
        title: "Kardiyoloji Özeti",
        detail: "2 bölüm",
        content: .object([
            "summary": .string("Kalp yetmezliği temel noktalar."),
            "must_know": .array([.string("Ekokardiyografi"), .string("BNP")])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 2,
        jobId: "job-export"
    )

    let text = SBStudyExportService.exportText(output.studyDocument)
    #expect(text.contains("Kardiyoloji Özeti"))
    #expect(text.contains("Medasi SourceBase"))
    #expect(text.contains("Mutlaka Bil"))
    #expect(text.contains("• BNP"))
}

@MainActor
@Test func completedFileCanGenerateEvenWhenSizeLabelIsMissing() async throws {
    let file = DriveFile(
        id: "file-ready",
        title: "Eksik boyut etiketi.pdf",
        kind: .pdf,
        sizeLabel: "-",
        pageLabel: "Sayfa bilgisi yok",
        updatedLabel: "Bugün",
        courseTitle: "Dahiliye",
        sectionTitle: "Kardiyoloji",
        status: .completed,
        statusMessage: nil,
        tag: nil,
        featured: false,
        selected: false,
        generated: []
    )

    #expect(file.isReadyForGeneration)
    #expect(SourceBaseWorkspaceStore.shared.isReadyForGeneration(file))
}

@Test func generatedOutputDecodesFlashcardsForStudyScreen() async throws {
    let output = GeneratedOutput(
        id: "output-1",
        sourceFileId: "file-1",
        kind: .flashcard,
        rawType: "flashcard",
        title: "Flashcard",
        detail: "2 kart",
        content: .object([
            "cards": .array([
                .object([
                    "front": .string("Beta bloker etkisi?"),
                    "back": .string("Kalp hızını ve kontraktiliteyi azaltır."),
                    "explanation": .string("Sempatik tonusu azaltır.")
                ])
            ])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-1"
    )

    #expect(output.flashcards.count == 1)
    #expect(output.flashcards.first?.front == "Beta bloker etkisi?")
}

@Test func generatedOutputDecodesPodcastAudioAndInfographicAssetUrls() async throws {
    let podcast = GeneratedOutput(
        id: "output-podcast",
        sourceFileId: "file-1",
        kind: .podcast,
        rawType: "podcast",
        title: "Podcast",
        detail: "Ses",
        content: .object([
            "title": .string("Kardiyoloji Podcast"),
            "audioFileUrl": .string("https://cdn.example.com/kardiyoloji.m4a"),
            "segments": .array([
                .object([
                    "title": .string("Giriş"),
                    "script": .string("Kalp yetmezliği anlatımı.")
                ])
            ])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-podcast"
    )
    let infographic = GeneratedOutput(
        id: "output-infographic",
        sourceFileId: "file-1",
        kind: .infographic,
        rawType: "infographic",
        title: "İnfografik",
        detail: "Görsel",
        content: .object([
            "title": .string("Kardiyoloji İnfografik"),
            "assetUrl": .string("https://cdn.example.com/kardiyoloji.png"),
            "sections": .array([
                .object([
                    "heading": .string("Ana mesaj"),
                    "bullets": .array([.string("Konjesyonu erken tanı.")])
                ])
            ])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-info"
    )

    #expect(podcast.podcastContent.audioURL?.absoluteString == "https://cdn.example.com/kardiyoloji.m4a")
    #expect(podcast.studyDocument.blocks.contains { if case .audio(_, let url, let segments) = $0 { return url?.pathExtension == "m4a" && segments.count == 1 }; return false })
    #expect(infographic.infographicContent.imageURL?.absoluteString == "https://cdn.example.com/kardiyoloji.png")
    #expect(infographic.studyDocument.blocks.contains { if case .image(_, let url, _) = $0 { return url?.lastPathComponent == "kardiyoloji.png" }; return false })
}

@Test func mediaGenerationContractsRequestExportableAssets() async throws {
    let podcast = SourceBaseGenerationContract.contract(for: .podcast, mode: "15 dk", source: nil)
    let infographic = SourceBaseGenerationContract.contract(for: .infographic, mode: "Dikey", source: nil)

    #expect(podcast.outputContract.contains("audio_url"))
    #expect(podcast.outputContract.contains("m4a/mp3"))
    #expect(infographic.outputContract.contains("image_url"))
    #expect(infographic.outputContract.contains("paylaşılabilir görsel"))
    #expect(podcast.aiBrief.contains("Drive seçimini kesin bağlam"))
}

@Test func rawTextOutputsStillRenderAsTypeSpecificStudyBlocks() async throws {
    for kind in GeneratedKind.allCases {
        let output = GeneratedOutput(
            id: "raw-\(kind.rawValue)",
            sourceFileId: "file-raw",
            kind: kind,
            rawType: kind.rawValue,
            title: kind.titleLabel,
            detail: "Ham metin",
            contentText: """
            \(kind.titleLabel) ana çıktı
            Birinci kaynak noktası
            İkinci kaynak noktası
            Üçüncü kaynak noktası
            """,
            updatedLabel: "Bugün",
            status: "ready",
            itemCount: 3,
            jobId: "job-\(kind.rawValue)"
        )

        let document = output.studyDocument
        #expect(!document.blocks.isEmpty, "\(kind.rawValue) boş çalışma ekranına düşmemeli")
        #expect(!document.blocks.contains { blockTitle($0) == "Çalışma Notları" }, "\(kind.rawValue) generic not fallback'ine düşmemeli")

        switch kind {
        case .flashcard:
            #expect(document.blocks.contains { if case .cards = $0 { return true }; return false })
        case .question:
            #expect(document.blocks.contains { if case .calloutList(_, "Soru Taslağı", _, .objective) = $0 { return true }; return false })
        case .summary:
            #expect(document.blocks.contains { if case .calloutList(_, "Yüksek Verimli Notlar", _, .mustKnow) = $0 { return true }; return false })
        case .examMorningSummary:
            #expect(document.blocks.contains { if case .calloutList(_, "Sınav Sabahı Notları", _, .mustKnow) = $0 { return true }; return false })
        case .algorithm:
            #expect(document.blocks.contains { if case .steps(_, "Akış Adımları", _) = $0 { return true }; return false })
        case .comparison, .table:
            #expect(document.blocks.contains { if case .table(_, "Karşılaştırma", let table) = $0 { return table.headers == ["Kriter", "Kaynak Notu"] }; return false })
        case .clinicalScenario:
            #expect(document.blocks.contains { if case .calloutList(_, "Klinik Noktalar", _, .tip) = $0 { return true }; return false })
        case .learningPlan:
            #expect(document.blocks.contains { if case .timeline(_, "Çalışma Oturumları", _) = $0 { return true }; return false })
        case .podcast:
            #expect(document.blocks.contains { if case .audio(_, _, let segments) = $0 { return !segments.isEmpty }; return false })
        case .infographic:
            #expect(document.blocks.contains { if case .calloutList(_, "Öne Çıkanlar", _, .plain) = $0 { return true }; return false })
        case .mindMap:
            #expect(document.blocks.contains { if case .mindBranches(_, "Dallar", _) = $0 { return true }; return false })
        }
    }
}

@Test func studyParserAcceptsBackendSnakeAndCamelCaseQualityFields() async throws {
    let clinical = GeneratedOutput(
        id: "clinical-snake",
        sourceFileId: "file-1",
        kind: .clinicalScenario,
        rawType: "clinical_scenario",
        title: "Klinik",
        detail: "",
        content: .object([
            "patient_info": .string("56 yaş erkek"),
            "chief_complaint": .string("Dispne"),
            "case_stem": .string("Eforla artan nefes darlığı."),
            "physical_exam": .array([.string("Ral")]),
            "labs_imaging": .array([.string("BNP yüksek")]),
            "problem_representation": .array([.string("Efor dispnesi ve konjesyon bulgusu olan hasta")]),
            "differential_diagnosis": .array([.string("Kalp yetmezliği")]),
            "diagnostic_justification": .array([.string("BNP yüksekliği ve ral konjesyonu destekler.")]),
            "decisionNodes": .array([
                .object([
                    "title": .string("Hipotansiyon var mı?"),
                    "yes": .string("Acil değerlendir"),
                    "no": .string("Standart tedaviye geç")
                ])
            ]),
            "teaching_points": .array([.string("Konjesyonu erken ayır.")])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-clinical"
    )
    let algorithm = GeneratedOutput(
        id: "algorithm-camel",
        sourceFileId: "file-1",
        kind: .algorithm,
        rawType: "algorithm",
        title: "Algoritma",
        detail: "",
        content: .object([
            "startingPoint": .string("Dispne"),
            "decisionNodes": .array([
                .object([
                    "title": .string("Konjesyon bulgusu"),
                    "subSteps": .array([.string("Ödem bak"), .string("Akciğer dinle")])
                ])
            ]),
            "actionSteps": .array([.string("Oksijen ihtiyacını değerlendir")]),
            "criticalThresholds": .array([.string("Satürasyon düşükse acil")])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-algorithm"
    )
    let plan = GeneratedOutput(
        id: "plan-snake",
        sourceFileId: "file-1",
        kind: .learningPlan,
        rawType: "learning_plan",
        title: "Plan",
        detail: "",
        content: .object([
            "study_sessions": .array([
                .object([
                    "title": .string("Oturum 1"),
                    "estimated_minutes": .integer(25),
                    "activities": .array([.string("Özet oku"), .string("10 soru çöz")])
                ])
            ]),
            "start_today": .array([.string("İlk 25 dakikayı tamamla")]),
            "daily_goals": .array([.string("Yanlışları not et")]),
            "weak_points": .array([.string("Ayırıcı tanı")])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-plan"
    )

    #expect(clinical.studyDocument.blocks.contains { if case .keyValues(_, "Vaka Bilgisi", let pairs) = $0 { return pairs.contains { $0.value == "56 yaş erkek" } }; return false })
    #expect(clinical.studyDocument.blocks.contains { if case .calloutList(_, "Problem Temsili", let items, .mustKnow) = $0 { return items.first?.contains("Efor dispnesi") == true }; return false })
    #expect(clinical.studyDocument.blocks.contains { if case .calloutList(_, "Tanısal Gerekçe", let items, .tip) = $0 { return items.first?.contains("BNP") == true }; return false })
    #expect(clinical.studyDocument.blocks.contains { if case .decisions(_, "Karar Noktaları", let nodes) = $0 { return nodes.first?.title == "Hipotansiyon var mı?" }; return false })
    #expect(algorithm.studyDocument.blocks.contains { if case .steps(_, "Eylem Adımları", let items) = $0 { return items.contains("Oksijen ihtiyacını değerlendir") }; return false })
    #expect(algorithm.studyDocument.blocks.contains { if case .calloutList(_, "Kritik Eşikler", let items, .mustKnow) = $0 { return items.contains("Satürasyon düşükse acil") }; return false })
    #expect(plan.studyDocument.blocks.contains { if case .timeline(_, "Çalışma Oturumları", let entries) = $0 { return entries.first?.items.count == 2 }; return false })
    #expect(plan.studyDocument.blocks.contains { if case .calloutList(_, "Bugün Başla", let items, .mustKnow) = $0 { return items.contains("İlk 25 dakikayı tamamla") }; return false })
}

@Test func generatedOutputAcceptsQlinikCompatibleFiveChoiceQuestions() async throws {
    let output = GeneratedOutput(
        id: "output-2",
        sourceFileId: "file-1",
        kind: .question,
        rawType: "question",
        title: "Soru",
        detail: "1 soru",
        content: .object([
            "questions": .array([
                .object([
                    "text": .string("Hangisi doğrudur?"),
                    "options": .array([.string("A"), .string("B"), .string("C"), .string("D"), .string("E")]),
                    "correct_index": .integer(4),
                    "explanation": .string("E doğrudur.")
                ])
            ])
        ]),
        updatedLabel: "Bugün",
        status: "ready",
        itemCount: 1,
        jobId: "job-2"
    )

    #expect(output.qlinikCompatibleQuestions.count == 1)
    #expect(output.qlinikCompatibleQuestions.first?.options.count == 5)
}

@MainActor
@Test func workspaceFriendlyErrorHidesServerDetails() async throws {
    let error = DriveAPIError(
        message: "backend job type is not enabled on edge function",
        code: "JOB_TYPE_DISABLED",
        status: 500
    )

    let message = SourceBaseWorkspaceStore.shared.friendlyError(error)
    #expect(message == "İşlem şu anda hazırlanamadı. Biraz sonra tekrar deneyebilirsin.")
}

@MainActor
@Test func workspaceFriendlyErrorExplainsScannedPDF() async throws {
    let error = DriveAPIError(
        message: "OCR_REQUIRED no text found in scanned pdf",
        code: "OCR_REQUIRED",
        status: 422
    )

    let message = SourceBaseWorkspaceStore.shared.friendlyError(error)
    #expect(message == "Bu PDF görüntü tabanlı görünüyor. OCR/metin çıkarımı sonuç vermedi; daha net tarama veya metin içeren PDF deneyebilirsin.")
}

@MainActor
@Test func workspaceFriendlyErrorExplainsEncryptedAndCorruptFiles() async throws {
    let encrypted = DriveAPIError(
        message: "FILE_ENCRYPTED_PDF password protected",
        code: "FILE_ENCRYPTED_PDF",
        status: 422
    )
    #expect(SourceBaseWorkspaceStore.shared.friendlyError(encrypted) == "Bu PDF şifreli görünüyor. Şifre korumasını kaldırıp tekrar yükleyebilirsin.")

    let corrupt = DriveAPIError(
        message: "corrupt file package",
        code: "FILE_CORRUPT",
        status: 422
    )
    #expect(SourceBaseWorkspaceStore.shared.friendlyError(corrupt) == "Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin.")
}

@MainActor
@Test func workspaceFriendlyErrorExplainsLegacyOfficeFallbacks() async throws {
    let ppt = DriveAPIError(
        message: "FILE_TYPE_LIMITED_SUPPORT old ppt parser unavailable",
        code: "FILE_TYPE_LIMITED_SUPPORT",
        status: 422
    )
    #expect(SourceBaseWorkspaceStore.shared.friendlyError(ppt) == "Eski PPT dosyaları sınırlı desteklenir. Dosyayı PPTX olarak kaydedip tekrar yükleyebilirsin.")

    let doc = DriveAPIError(
        message: "old doc parser unavailable",
        code: "FILE_TYPE_LIMITED_SUPPORT",
        status: 422
    )
    #expect(SourceBaseWorkspaceStore.shared.friendlyError(doc) == "Eski DOC dosyaları sınırlı desteklenir. Dosyayı DOCX olarak kaydedip tekrar yükleyebilirsin.")
}

@MainActor
@Test func workspaceExposesExplicitUploadDestinations() async throws {
    let file = DriveFile(
        id: "file-1",
        title: "Anatomi.pdf",
        kind: .pdf,
        sizeLabel: "1 MB",
        pageLabel: "10 sayfa",
        updatedLabel: "Bugün",
        courseTitle: "Anatomi",
        sectionTitle: "Kas",
        status: .completed,
        statusMessage: nil,
        tag: nil,
        featured: false,
        selected: false,
        generated: []
    )
    let section = DriveSection(id: "section-1", title: "Kas", status: .completed, files: [file])
    let course = DriveCourse(
        id: "course-1",
        title: "Anatomi",
        iconName: "book",
        iconColorHex: "#000000",
        iconBackgroundHex: "#FFFFFF",
        status: .completed,
        sections: [section],
        updatedLabel: "Bugün",
        description: "Test"
    )

    let store = SourceBaseWorkspaceStore.shared
    store.workspace = DriveWorkspaceData(courses: [course], recentFiles: [file], uploads: [], collections: [])
    store.selectedCourseId = "course-1"
    store.selectedSectionId = "section-1"

    #expect(store.availableDestinations == [
        DriveDestination(courseId: "course-1", sectionId: "section-1", courseTitle: "Anatomi", sectionTitle: "Kas")
    ])
    #expect(store.preferredUploadDestination?.sectionId == "section-1")
}

@MainActor
@Test func workspaceSelectionPromotesChosenPdfCourseAndSection() async throws {
    let anatomyFile = DriveFile(
        id: "file-anatomi",
        title: "Anatomi.pdf",
        kind: .pdf,
        sizeLabel: "1 MB",
        pageLabel: "10 sayfa",
        updatedLabel: "Bugün",
        courseTitle: "Anatomi",
        sectionTitle: "Kas",
        status: .completed,
        statusMessage: nil,
        tag: nil,
        featured: false,
        selected: false,
        generated: []
    )
    let cardioFile = DriveFile(
        id: "file-kardiyo",
        title: "Kalp Yetmezliği.pdf",
        kind: .pdf,
        sizeLabel: "2 MB",
        pageLabel: "24 sayfa",
        updatedLabel: "Bugün",
        courseTitle: "Dahiliye",
        sectionTitle: "Kardiyoloji",
        status: .completed,
        statusMessage: nil,
        tag: nil,
        featured: false,
        selected: false,
        generated: []
    )
    let store = SourceBaseWorkspaceStore.shared
    store.workspace = DriveWorkspaceData(
        courses: [
            DriveCourse(id: "course-a", title: "Anatomi", iconName: "book", iconColorHex: "#000", iconBackgroundHex: "#FFF", status: .completed, sections: [
                DriveSection(id: "section-a", title: "Kas", status: .completed, files: [anatomyFile])
            ], updatedLabel: "Bugün", description: ""),
            DriveCourse(id: "course-d", title: "Dahiliye", iconName: "book", iconColorHex: "#000", iconBackgroundHex: "#FFF", status: .completed, sections: [
                DriveSection(id: "section-k", title: "Kardiyoloji", status: .completed, files: [cardioFile])
            ], updatedLabel: "Bugün", description: "")
        ],
        recentFiles: [],
        uploads: [],
        collections: []
    )
    store.selectedFileId = nil
    store.selectedCourseId = nil
    store.selectedSectionId = nil

    store.setSelectedSources(["file-kardiyo"])

    #expect(store.selectedReadyFiles.map(\.id) == ["file-kardiyo"])
    #expect(store.selectedFileId == "file-kardiyo")
    #expect(store.selectedCourseId == "course-d")
    #expect(store.selectedSectionId == "section-k")
}

private func blockTitle(_ block: SBStudyBlock) -> String {
    switch block {
    case .paragraph:
        return ""
    case let .calloutList(_, title, _, _),
         let .steps(_, title, _),
         let .decisions(_, title, _),
         let .table(_, title, _),
         let .keyValues(_, title, _),
         let .qa(_, title, _),
         let .timeline(_, title, _),
         let .mindBranches(_, title, _):
        return title
    case .cards:
        return "Kartlar"
    case .quiz:
        return "Quiz"
    case let .image(_, _, caption):
        return caption
    case .audio:
        return "Ses"
    }
}
