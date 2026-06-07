import SwiftUI
import SourceBaseBackend

/// Minimal "generation started" screen: kicks off the job, shows a clean
/// 3-second countdown, then hands the user to the queue. No verbose steps.
struct GenerationProcessingView: View {
    let sourceFileId: String
    let kindRawValue: String
    let label: String
    let surface: String
    let mode: String
    var extraOptions: [String: String] = [:]

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var didStart = false
    @State private var countdown = 3
    @State private var errorMessage: String?

    private var router: AppRouter { appState.router }
    private var kind: GeneratedKind { GeneratedKind(rawValue: kindRawValue) ?? .summary }
    private var accent: Color { SBOutputStyle.outputColor(kind) }
    private var contract: SourceBaseGenerationContract {
        SourceBaseGenerationContract.contract(for: kind, mode: mode, source: workspaceStore.file(id: sourceFileId))
    }

    var body: some View {
        VStack(spacing: SBSpacing.xl) {
            Spacer()
            if let errorMessage {
                errorState(errorMessage)
            } else {
                startedState
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SBSpacing.xl)
        .sbReadableWidth(540)
        .sbPageBackground(tone: .cool)
        .navigationBarBackButtonHidden(errorMessage == nil)
        .task { await startIfNeeded() }
    }

    // MARK: - Started

    private var startedState: some View {
        VStack(spacing: SBSpacing.lg) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 132, height: 132)
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 3)
                    .frame(width: 132, height: 132)
                Text("\(countdown)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText(countsDown: true))
                    .id(countdown)
            }
            .sbCompletionGlow(true, tint: accent)

            VStack(spacing: SBSpacing.xs) {
                Text("Üretim başladı")
                    .font(SBTypography.titleLarge)
                    .foregroundStyle(SBColors.navy)
                Text("\(SBOutputStyle.templateName(kind)) kuyruğa eklendi. Hazır olunca bildireceğiz.")
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        VStack(spacing: SBSpacing.md) {
            SBErrorState(
                title: "Üretim başlatılamadı",
                message: message,
                actionLabel: "Tekrar dene",
                onAction: { restart() },
                context: .generation
            )
            SBButton("Kuyruğa git", icon: "clock", variant: .secondary, size: .medium, fullWidth: true) {
                router.replaceCurrent(with: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
            }
        }
    }

    // MARK: - Flow

    private func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        guard let source = workspaceStore.file(id: sourceFileId) ?? workspaceStore.readyFiles.first else {
            await workspaceStore.loadWorkspace()
            guard let reloaded = workspaceStore.file(id: sourceFileId) else {
                errorMessage = "Bu kaynak üretim için hazır değil. Drive'dan hazır bir kaynak seç."
                return
            }
            await launch(source: reloaded)
            return
        }
        await launch(source: source)
    }

    private func launch(source: DriveFile) async {
        let job = await workspaceStore.startGeneration(file: source, kind: kind, options: generationOptions)
        guard job != nil else {
            errorMessage = workspaceStore.toastMessage ?? "Üretim başlatılamadı. Tekrar dene."
            return
        }
        SBHaptics.success()
        await countdownThenQueue()
    }

    private func countdownThenQueue() async {
        for value in stride(from: 3, through: 1, by: -1) {
            withAnimation(SBMotion.spring) { countdown = value }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        router.replaceCurrent(with: .queue(surface: SourceBaseQueueSurface.surface(for: kind)))
    }

    private func restart() {
        errorMessage = nil
        countdown = 3
        didStart = false
        Task { await startIfNeeded() }
    }

    // MARK: - Options

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
            "qualityGate": contract.qualityGate,
            "quality_gate": contract.qualityGate,
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
        }
        if let count = requestedCount {
            options["count"] = String(count)
        }
        if kind == .question {
            options["optionCount"] = "5"
            options["schema"] = "qlinik_public_review_v1"
            options["persistCandidateQuestions"] = "true"
        }
        options.merge(extraOptions) { existing, _ in existing }
        return options
    }

    private var requestedCount: Int? {
        mode.matches(of: /\d+/).compactMap { Int(String($0.output)) }.last
    }
}

#Preview {
    NavigationStack {
        GenerationProcessingView(
            sourceFileId: "preview-source",
            kindRawValue: GeneratedKind.flashcard.rawValue,
            label: "Flashcard Seti",
            surface: "Üret Flashcard",
            mode: "Dengeli"
        )
        .environment(AppState.shared)
        .environment(SourceBaseWorkspaceStore.shared)
    }
}
