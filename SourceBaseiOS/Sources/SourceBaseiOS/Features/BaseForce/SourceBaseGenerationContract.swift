import Foundation
import SourceBaseBackend

struct SourceBaseGenerationContract {
    let qualityTier: String
    let modelPolicy: String
    let minimumDepth: String
    let outputLengthPolicy: String
    let imageModelPolicy: String?
    let sourceReadPolicy: String
    let sourceCoveragePolicy: String
    let sourceChunkPolicy: String
    let modelRouterPolicy: String
    let preferredModelTier: String
    let qualityGate: String
    let learningSciencePolicy: String
    let retrievalPracticePolicy: String
    let spacedReviewPolicy: String
    let clinicalReasoningPolicy: String
    let studentOutcomeContract: String
    let aiBrief: String
    let outputContract: String
    let preflightChecks: [PreflightCheck]
    let factoryBadges: [String]

    struct PreflightCheck: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    static func contract(for kind: GeneratedKind, mode: String, source: DriveFile?) -> SourceBaseGenerationContract {
        let sourceLabel = source.map { "\($0.courseTitle) / \($0.sectionTitle) / \($0.title)" } ?? "Seçili Drive kaynağı"
        let policy = generationPolicy(for: kind, mode: mode)
        return SourceBaseGenerationContract(
            qualityTier: policy.qualityTier,
            modelPolicy: policy.modelPolicy,
            minimumDepth: policy.minimumDepth,
            outputLengthPolicy: policy.outputLengthPolicy,
            imageModelPolicy: policy.imageModelPolicy,
            sourceReadPolicy: sourceReadPolicy(for: kind),
            sourceCoveragePolicy: sourceCoveragePolicy(for: kind),
            sourceChunkPolicy: sourceChunkPolicy(for: kind),
            modelRouterPolicy: modelRouterPolicy(for: kind),
            preferredModelTier: preferredModelTier(for: kind, qualityTier: policy.qualityTier),
            qualityGate: qualityGate(for: kind),
            learningSciencePolicy: learningSciencePolicy(for: kind),
            retrievalPracticePolicy: "force_commit_before_answer_with_self_check_or_questions",
            spacedReviewPolicy: "include_today_24h_72h_7d_review_prompts_when_applicable",
            clinicalReasoningPolicy: "problem_representation_differential_justification_red_flags_and_management_frame",
            studentOutcomeContract: studentOutcomeContract(for: kind),
            aiBrief: aiBrief(for: kind, mode: mode, sourceLabel: sourceLabel),
            outputContract: outputContract(for: kind, mode: mode),
            preflightChecks: preflightChecks(for: kind, mode: mode, sourceLabel: sourceLabel),
            factoryBadges: factoryBadges(for: kind)
        )
    }

    private struct GenerationPolicy {
        let qualityTier: String
        let modelPolicy: String
        let minimumDepth: String
        let outputLengthPolicy: String
        let imageModelPolicy: String?
    }

    private enum QualitySelection: String {
        case economy
        case standard
        case premium
    }

    private static func generationPolicy(for kind: GeneratedKind, mode: String) -> GenerationPolicy {
        let quality = requestedQualitySelection(from: mode)

        if quality == .economy {
            return GenerationPolicy(
                qualityTier: "economy",
                modelPolicy: premiumEfficientModelPolicy(for: kind),
                minimumDepth: premiumEfficientMinimumDepth(for: kind),
                outputLengthPolicy: premiumEfficientOutputLengthPolicy(for: kind),
                imageModelPolicy: kind == .infographic ? infographicImageModel(for: quality) : nil
            )
        }

        let imageModelPolicy = kind == .infographic ? infographicImageModel(for: quality) : nil

        if quality == .standard {
            return GenerationPolicy(
                qualityTier: "standard",
                modelPolicy: premiumBalancedModelPolicy(for: kind),
                minimumDepth: premiumBalancedMinimumDepth(for: kind),
                outputLengthPolicy: premiumBalancedOutputLengthPolicy(for: kind),
                imageModelPolicy: imageModelPolicy
            )
        }

        return GenerationPolicy(
            qualityTier: "premium",
            modelPolicy: premiumPlusModelPolicy(for: kind),
            minimumDepth: premiumPlusMinimumDepth(for: kind),
            outputLengthPolicy: premiumPlusOutputLengthPolicy(for: kind),
            imageModelPolicy: imageModelPolicy
        )
    }

    private static func requestedQualitySelection(from mode: String) -> QualitySelection {
        let normalized = mode.lowercased()
        if normalized.contains("ekonomik")
            || normalized.contains("economy")
            || normalized.contains("ucuz") {
            return .economy
        }
        if normalized.contains("premium")
            || normalized.contains("en iyi")
            || normalized.contains("en üst") {
            return .premium
        }
        // Standart, kullanıcı aksini seçmedikçe dengeli varsayılan kalitedir:
        // iyi sonuç + adil MC. Kullanıcı ekonomik/premium ile değiştirir.
        return .standard
    }

    private static func infographicImageModel(for quality: QualitySelection) -> String {
        switch quality {
        case .economy:
            return "gpt-image-1-mini"
        case .standard:
            return "gpt-image-1.5"
        case .premium:
            return "gpt-image-2"
        }
    }

    private static func premiumEfficientModelPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .infographic:
            return "premium_efficient_long_context_visual_quality_first"
        case .clinicalScenario:
            return "premium_efficient_long_context_clinical_reasoning_first"
        case .question:
            return "premium_efficient_long_context_assessment_quality_first"
        case .comparison, .table:
            return "premium_efficient_long_context_matrix_reasoning_first"
        case .podcast:
            return "premium_efficient_long_context_longform_learning_quality"
        case .flashcard:
            return "premium_efficient_long_context_active_recall_quality_first"
        case .summary:
            return "premium_efficient_long_context_summary_synthesis_first"
        case .learningPlan:
            return "premium_efficient_long_context_adaptive_study_planning"
        case .examMorningSummary, .algorithm, .mindMap:
            return "premium_efficient_long_context_structured_reasoning_first"
        }
    }

    private static func premiumBalancedModelPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .infographic:
            return "premium_balanced_long_context_visual_quality_first"
        case .clinicalScenario:
            return "premium_balanced_long_context_clinical_reasoning_first"
        case .question:
            return "premium_balanced_long_context_assessment_quality_first"
        case .comparison, .table:
            return "premium_balanced_long_context_matrix_reasoning_first"
        case .podcast:
            return "premium_balanced_long_context_longform_learning_quality"
        case .flashcard:
            return "premium_balanced_long_context_active_recall_quality_first"
        case .summary:
            return "premium_balanced_long_context_summary_synthesis_first"
        case .learningPlan:
            return "premium_balanced_long_context_adaptive_study_planning"
        case .examMorningSummary, .algorithm, .mindMap:
            return "premium_balanced_long_context_structured_reasoning_first"
        }
    }

    private static func premiumPlusModelPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .infographic:
            return "premium_latest_long_context_visual_quality_first"
        case .clinicalScenario:
            return "premium_latest_long_context_clinical_reasoning_first"
        case .question:
            return "premium_latest_long_context_assessment_quality_first"
        case .comparison, .table:
            return "premium_latest_long_context_matrix_reasoning_first"
        case .podcast:
            return "premium_latest_long_context_longform_learning_quality"
        case .flashcard:
            return "premium_latest_long_context_active_recall_quality_first"
        case .summary:
            return "premium_latest_long_context_summary_synthesis_first"
        case .learningPlan:
            return "premium_latest_long_context_adaptive_study_planning"
        case .examMorningSummary, .algorithm, .mindMap:
            return "premium_latest_long_context_structured_reasoning_first"
        }
    }

    private static func premiumEfficientMinimumDepth(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "efficient_full_source_matrix_deep"
        case .clinicalScenario:
            return "efficient_clinical_deep_with_differential"
        case .question:
            return "efficient_assessment_deep_with_distractor_rationales"
        case .podcast:
            return "efficient_longform_deep_segmented"
        case .infographic:
            return "efficient_visual_detailed_with_text_fallback"
        default:
            return "premium_efficient_deep_with_gap_analysis"
        }
    }

    private static func premiumBalancedMinimumDepth(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "balanced_full_source_matrix_deep"
        case .clinicalScenario:
            return "balanced_clinical_deep_with_differential"
        case .question:
            return "balanced_assessment_deep_with_distractor_rationales"
        case .podcast:
            return "balanced_longform_deep_segmented"
        case .infographic:
            return "balanced_visual_detailed_with_text_fallback"
        default:
            return "premium_balanced_deep"
        }
    }

    private static func premiumPlusMinimumDepth(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "full_source_matrix_deep"
        case .clinicalScenario:
            return "clinical_deep_with_differential"
        case .question:
            return "assessment_deep_with_distractor_rationales"
        case .podcast:
            return "longform_deep_segmented"
        case .infographic:
            return "visual_detailed_with_text_fallback"
        default:
            return "premium_deep"
        }
    }

    private static func premiumEfficientOutputLengthPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard, .question:
            return "complete_set_compact_explanations_not_short"
        case .podcast:
            return "compact_longform_complete_not_padded"
        default:
            return "compact_structured_but_complete"
        }
    }

    private static func premiumBalancedOutputLengthPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard, .question:
            return "complete_set_balanced_explanations_not_short"
        case .podcast:
            return "balanced_longform_complete_not_padded"
        default:
            return "balanced_comprehensive_structured_not_short"
        }
    }

    private static func premiumPlusOutputLengthPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard, .question:
            return "complete_set_not_short"
        case .podcast:
            return "longform_comprehensive_not_padded"
        case .infographic:
            return "comprehensive_visual_structured"
        default:
            return "comprehensive_structured_not_short"
        }
    }

    private static func sourceReadPolicy(for kind: GeneratedKind) -> String {
        "read_full_extracted_document_not_first_excerpt"
    }

    private static func sourceCoveragePolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "cover_all_selected_sources_beginning_middle_end_headings_tables_conclusions_and_criteria"
        case .question:
            return "cover_all_testable_objectives_beginning_middle_end_tables_figures_and_misconceptions"
        case .flashcard:
            return "cover_all_core_concepts_beginning_middle_end_tables_figures_and_common_mistakes"
        case .algorithm:
            return "cover_all_decision_points_thresholds_exceptions_tables_and_red_flags"
        case .clinicalScenario:
            return "cover_full_case_relevant_source_history_findings_labs_treatment_red_flags_and_limits"
        case .podcast:
            return "cover_full_source_as_episode_outline_beginning_middle_end_tables_and_recap"
        case .infographic:
            return "cover_full_source_visual_hierarchy_main_message_blocks_warnings_and_text_fallback"
        case .learningPlan:
            return "cover_full_source_objectives_weak_points_sessions_review_and_gap_closure"
        case .mindMap:
            return "cover_full_source_branch_hierarchy_cross_links_confusions_and_clinical_ties"
        case .summary, .examMorningSummary:
            return "cover_full_source_beginning_middle_end_headings_tables_conclusions_red_flags_and_self_check"
        }
    }

    private static func sourceChunkPolicy(for kind: GeneratedKind) -> String {
        "adaptive_full_document_chunk_map_reduce_for_long_sources"
    }

    private static func modelRouterPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table, .clinicalScenario, .podcast, .infographic:
            return "route_to_long_context_high_reasoning_model_for_large_or_sparse_sources"
        default:
            return "route_to_long_context_reasoning_model_when_source_exceeds_single_context_or_quality_gate_fails"
        }
    }

    private static func preferredModelTier(for kind: GeneratedKind, qualityTier: String) -> String {
        if qualityTier == "economy" {
            return "latest_premium_efficient_long_context"
        }
        if qualityTier == "standard" {
            return "latest_premium_balanced_long_context"
        }
        switch kind {
        case .comparison, .table, .clinicalScenario, .podcast, .infographic:
            return "latest_premium_high_reasoning_long_context"
        default:
            return "latest_premium_reasoning_long_context"
        }
    }

    private static func qualityGate(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "reject_first_excerpt_surface_table_or_under_8_criteria_without_source_gap"
        case .flashcard:
            return "reject_too_few_atomic_cards_or_generic_front_back_pairs"
        case .question:
            return "reject_shallow_questions_missing_rationales_source_coverage_or_real_distractors"
        default:
            return "reject_surface_level_first_excerpt_single_paragraph_or_underfilled_structured_output"
        }
    }

    private static func learningSciencePolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard:
            return "retrieval_practice_atomic_cards_spaced_review_common_mistake_feedback"
        case .question:
            return "test_enhanced_learning_five_choice_commitment_rationales_error_correction"
        case .clinicalScenario:
            return "case_based_clinical_reasoning_problem_representation_differential_justification_feedback"
        case .learningPlan:
            return "spaced_practice_interleaving_retrieval_checkpoints_gap_closure"
        case .podcast:
            return "dual_coding_audio_recap_retrieval_pauses_and_later_review_prompts"
        case .infographic, .mindMap:
            return "dual_coding_visual_hierarchy_active_recall_and_common_confusion_links"
        case .summary, .examMorningSummary, .algorithm, .comparison, .table:
            return "spaced_practice_retrieval_practice_interleaving_elaboration_dual_coding_concrete_examples"
        }
    }

    private static func studentOutcomeContract(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard:
            return "student_can_cover_answer_recall_explain_common_mistake_and_schedule_next_review"
        case .question:
            return "student_commits_to_answer_receives_rationale_reviews_wrong_options_and_knows_weak_topic"
        case .clinicalScenario:
            return "student_forms_problem_representation_lists_differential_justifies_top_diagnosis_and_names_red_flags"
        case .learningPlan:
            return "student_knows_what_to_do_today_next_24h_72h_7d_and_how_to_measure_progress"
        case .comparison, .table:
            return "student_can_distinguish_entities_by_same_criteria_exam_traps_source_refs_and_red_flags"
        case .algorithm:
            return "student_can_enter_from_symptom_or_finding_follow_decisions_and_stop_at_red_flags"
        case .podcast:
            return "student_can_list_key_points_after_listening_answer_recall_prompts_and_export_audio"
        case .infographic:
            return "student_can_scan_main_message_warnings_blocks_and_quick_check_without_plain_text_dump"
        case .mindMap:
            return "student_can_explain_central_concept_branches_cross_links_and_common_confusions"
        case .summary, .examMorningSummary:
            return "student_can_study_actively_review_later_identify_gaps_and_verify_source_grounding"
        }
    }

    private static func aiBrief(for kind: GeneratedKind, mode: String, sourceLabel: String) -> String {
        """
        BaseForce üretiminden önce kullanıcının tüm SourceBase çalışma alanını değerlendir: seçili kaynak, ders/bölüm bağlamı, önceki çıktılar ve kaynak düzenindeki eksikler. \
        Üretime başlamadan önce yanlış anlaşılabilecek kavramları, eksik kapsamları, çelişkili başlıkları ve sınav/klinik açıdan riskli boşlukları belirle. \
        Çıktıyı yalnızca kaynağa dayandır; belirsiz alanları uydurma, "kaynakta açık değil" diye işaretle. \
        Ücretli/premium çalışma ürünü gibi davran: ham özet çıkarma, öğrencinin tekrar ederken kullanacağı aktif hatırlama, ayırt ettiren ipucu, sık hata ve klinik güvenlik katmanlarını ekle. \
        Tıp öğrencisi ihtiyacı açık: aktif hatırlama, spaced review, interleaving, görsel/işitsel çift kodlama, vaka üzerinden klinik akıl yürütme, kaynak açığı ve kırmızı bayrak görünürlüğü. Çıktı öğrenciyi cevabı görmeden önce düşünmeye zorlamalı; çözümü doğrudan verip akıl yürütme adımını atlamamalı. \
        Kaynağın yalnızca girişini, ilk sayfalarını veya ilk excerpt'ünü okumak yasak: tam çıkarılmış dokümanı tara; 10 sayfalık kaynakta tamamını ayrıntılı oku, 200 sayfalık kaynakta chunk-map-reduce ile baş-orta-son, tüm başlıklar, tablolar, görselden çıkarılmış metinler, sonuç/slayt notları ve ek kaynakları sentezle. \
        Context yetersizse veya çıktı tipi kapsamlı tablo/karşılaştırma gerektiriyorsa long-context/reasoning model seviyesine yükselt; kısaltılmış ilk parça üzerinden nihai yanıt verme. \
        Yanıt tek paragraf, genel tavsiye veya kısa liste olarak dönmemeli; seçilen çıktı tipinin çalışma ekranını dolduracak kadar yapılandırılmış, görsel bloklara ayrılmış ve mobilde taranabilir olmalı. \
        Study workspace şemasıyla düşün: summary/overview yanında ana çalışma blokları, karar/akış blokları, kontrol/quiz blokları ve kaynakta eksik kalan yerleri ayrı alanlar halinde döndür. \
        Drive seçimini kesin bağlam kabul et: ders, bölüm ve seçili PDF/dosya havuzunun dışına taşma; birden çok kaynak seçildiyse hepsini aynı ders/bölüm mantığıyla sentezle ve kaynak sınırlarını açık yaz. \
        Kaynak: \(sourceLabel). Mod: \(kind.titleLabel). Ayarlar: \(mode).
        """
    }

    private static func outputContract(for kind: GeneratedKind, mode: String) -> String {
        switch kind {
        case .flashcard:
            return "Her kart atomik ön yüz, net cevap, ipucu, açıklama, sık hata ve kavram grubu içermeli. JSON kartları concept_group/topic/difficulty/hint/explanation alanlarıyla dönmeli; kullanıcı ekranda kartları çevirip bilme/tekrar kuyruğuna ayıracak. Varsayılan üretim 20 karttan kısa olmamalı; kısa kaynakta bile kapsamlı, ayırt etme odaklı aktif hatırlama seti kurulmalı. Ayarlar: \(mode)."
        case .question:
            return "Her soru 5 seçenekli, tek doğru cevaplı, Qlinik uyumlu, kaynak gerekçeli ve tüm yanlış seçenek açıklamalarıyla dönmeli. JSON questions içinde text/options/correct_index/explanation/option_rationales/tags/difficulty/topic alanları tam olmalı. Varsayılan set 10 sorudan kısa olmamalı; cevap çözüm ekranına kadar görünmemeli, çeldiriciler gerçek sınav tuzaklarını ölçmeli. Ayarlar: \(mode)."
        case .summary, .examMorningSummary:
            return "Özet tek kısa paragraf olmamalı; summary yanında high_yield_points/bulletPoints, must_know, commonly_confused, red_flags, mini_table veya rows/headers, clinicalDecisionFlow/algorithm_flow, source_gaps, self_check ve next_review_prompts alanlarıyla dönmeli. Kullanıcı ekranda Öğren/Akış/Kontrol katmanlarına ayrılmış çalışma paketi görecek; bugün, 24 saat, 72 saat ve 7 gün tekrar sinyali verilmeli. Ayarlar: \(mode)."
        case .algorithm:
            return "Algoritma starting_point, decision_nodes[{title,detail,yes,no,substeps}], action_steps, critical_thresholds, red_flags, exam_tips ve notes alanlarıyla dönmeli. Düz metin akış değil, mobil karar tahtası olarak çizilecek en az 5 anlamlı karar/aksiyon bloğu içermeli. Ayarlar: \(mode)."
        case .comparison, .table:
            return "Karşılaştırma tam kaynak matrisi olarak dönmeli: source_coverage, headers, criteria, rows[{criterion,values,distinguishing_tip,exam_trap,source_refs}], distinguishing_tips, clinical_notes, commonly_confused, red_flags ve short_takeaway alanları şart. Yalnızca giriş/ilk excerpt üzerinden tablo kurma; tüm seçili kaynakların baş-orta-son bölümlerini, tablolarını ve sonuç notlarını karşılaştır. En az 8 anlamlı kriter satırı üret veya kaynakta gerçekten daha az kriter varsa source_gaps içinde gerekçelendir; kriterler tanım/mekanizma/klinik/lab/tedavi/kontrendikasyon/kırmızı bayrak/sınav tuzağı gibi aynı eksende hizalanmalı. Kısa iki satırlık tablo veya genel prose yeterli değildir. Ayarlar: \(mode)."
        case .clinicalScenario:
            return "Vaka patientInfo/chiefComplaint/caseStem/history, physicalExam, labsImaging, problemRepresentation, differentialDiagnosis, diagnosticJustification, decision_nodes veya questions, red_flags, teachingPoints ve examTips alanlarıyla dönmeli. Kullanıcı vaka kartı, karar katmanı ve kontrol soruları görecek; klinik çıktı kısa veya yüzeysel olmamalı, ayırıcı tanı gerekçesi ve önemli negatif bulgu eksikleri görünmeli. Ayarlar: \(mode)."
        case .learningPlan:
            return "Plan sessions[{title,estimatedMinutes,activities}], startToday, dailyGoals, checklist, reviewDays, weakPoints, objectives ve questionFlashcardSuggestions alanlarıyla dönmeli. Uygulanabilir zaman blokları, tekrar aralıkları, mini ölçme adımları ve eksik kapatma görevleri şart; tek günlük kısa öneri listesi olarak dönmemeli. Ayarlar: \(mode)."
        case .podcast:
            return "Podcast title/durationLabel/audio_url/segments[{title,text,durationLabel}] ve recap/active_recall_prompts alanlarıyla dönmeli. Mümkünse dışa aktarılabilir m4a/mp3 ses dosyası üret ve URL'yi audio_url, audioFileUrl veya mp3_url alanlarından biriyle döndür; ses dosyası gecikirse tam transkript yine eksiksiz dönmeli. Metin konuşma dilinde, bölüm başlıklı, kaynak dışına çıkmayan açıklamalar, tekrar vurguları, kısa özetler ve aktif hatırlama sorularıyla hazırlanmalı; longform çalışma için yeterli segment ve transkript içermeli. Ayarlar: \(mode)."
        case .infographic:
            return "İnfografik title/main_message/image_url/sections[{heading,bullets}], warnings/red_flags, source_note ve quick_check alanlarıyla dönmeli. Mümkünse paylaşılabilir görsel dosya üret ve URL'yi image_url, imageUrl, assetUrl veya publicUrl alanlarından biriyle döndür. Tek ana mesaj, en az 5 kısa bilgi bloğu, kritik uyarılar ve hızlı tekrar sorusuyla görsel taramaya uygun olmalı. Görsel dosya hazırlanamazsa boş URL veya ham hata yerine aynı içeriği yapılandırılmış metin blokları olarak döndürmeli. Ayarlar: \(mode)."
        case .mindMap:
            return "Zihin haritası centralTopic, branches[{label,children,tags}], criticalConnections, commonly_confused ve clinicalTusTips alanlarıyla dönmeli. Merkez kavram, ana dallar, çapraz bağlantılar, karıştırılan noktalar ve klinik/sınav ilişkileriyle kurulmalı; en az 4 ana dal ve her dalda açıklayıcı çocuk başlıklar içermeli. Ayarlar: \(mode)."
        }
    }

    private static func preflightChecks(for kind: GeneratedKind, mode: String, sourceLabel: String) -> [PreflightCheck] {
        [
            PreflightCheck(
                icon: "square.stack.3d.up",
                title: "Kaynak kapsamı",
                detail: "\(sourceLabel) ve seçili kaynak havuzu çalışma kapsamı için denetlenir."
            ),
            PreflightCheck(
                icon: "exclamationmark.magnifyingglass",
                title: "Eksik ve yanlış analizi",
                detail: "Hatalı çıkarım, eksik konu, çelişkili başlık ve sık karıştırılan alanlar ayrılır."
            ),
            PreflightCheck(
                icon: "checkmark.seal",
                title: "Çıktı kontratı",
                detail: "\(kind.titleLabel) modu \(mode.isEmpty ? "standart ayarlar" : mode) ile kaynak dışına çıkmadan üretilir."
            )
        ]
    }

    private static func factoryBadges(for kind: GeneratedKind) -> [String] {
        switch kind {
        case .flashcard:
            return ["Kavram", "İpucu", "Sık hata"]
        case .question:
            return ["5 şık", "Açıklama", "Qlinik"]
        case .summary, .examMorningSummary:
            return ["High-yield", "Mini tablo", "Kontrol"]
        case .algorithm:
            return ["Karar düğümü", "Kırmızı bayrak", "Mobil akış"]
        case .comparison, .table:
            return ["Aynı kriter", "Ayırt ettiren", "Tuzak"]
        case .clinicalScenario:
            return ["Vaka", "Ayırıcı tanı", "Geri bildirim"]
        case .learningPlan:
            return ["Blok", "Tekrar", "Ölçme"]
        case .podcast:
            return ["Bölüm", "Konuşma dili", "Tekrar"]
        case .infographic:
            return ["Ana mesaj", "Blok", "Uyarı"]
        case .mindMap:
            return ["Merkez", "Dal", "Bağlantı"]
        }
    }
}
