import Foundation
import SourceBaseBackend

extension SourceBaseWorkspaceStore {
    public func enqueueDriveGeneration(
        file: DriveFile,
        kind: GeneratedKind,
        sourceIds: Set<String>? = nil,
        mode: String = "Standart"
    ) async -> SBGenerationJob? {
        let ids = sourceIds ?? [file.id]
        setSelectedSources(ids)
        selectFile(file)
        return await enqueueGeneration(
            file: file,
            kind: kind,
            label: kind.titleLabel,
            surface: "Üretim",
            mode: mode
        )
    }

    public func enqueueGeneration(
        file: DriveFile,
        kind: GeneratedKind,
        label: String,
        surface: String,
        mode: String,
        extraOptions: [String: String] = [:]
    ) async -> SBGenerationJob? {
        let contract = SourceBaseGenerationContract.contract(for: kind, mode: mode, source: file)
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

        if let count = Self.requestedCount(from: mode) {
            options["count"] = String(count)
        }

        if kind == .question {
            options["optionCount"] = "5"
            options["schema"] = "qlinik_public_review_v1"
            options["persistCandidateQuestions"] = "true"
        }

        options.merge(extraOptions) { existing, _ in existing }
        return await startGeneration(file: file, kind: kind, options: options)
    }

    private static func requestedCount(from mode: String) -> Int? {
        mode.matches(of: /\d+/)
            .compactMap { Int(String($0.output)) }
            .last
    }
}

extension AppRouter {
    public func showGenerationQueue(_: SourceBaseQueueSurface = .all) {
        switchTab(to: .baseForce)
        navigate(to: .queue(surface: .all))
    }
}
