import AVFoundation
import SwiftUI
import SourceBaseBackend

struct GeneratedOutputStudyView: View {
    let outputId: String

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var isLoading = true

    private var output: GeneratedOutput? {
        workspaceStore.generatedOutput(id: outputId)
    }

    var body: some View {
        Group {
            if isLoading {
                SBLoadingState(
                    icon: "rectangle.stack",
                    title: "Çalışma ekranı hazırlanıyor",
                    message: "Koleksiyon içeriği yükleniyor..."
                )
                .padding(SBSpacing.lg)
            } else if let output {
                studySurface(for: output)
                    .safeAreaInset(edge: .bottom) {
                        medicalDisclaimer
                    }
            } else {
                SBErrorState(
                    title: "Çıktı bulunamadı",
                    message: "Koleksiyon yenilenmiş olabilir. Koleksiyonlardan tekrar açmayı dene.",
                    actionLabel: "Koleksiyonlara Dön",
                    onAction: { appState.router.replaceCurrent(with: .collections) }
                )
                .padding(SBSpacing.lg)
            }
        }
        .sbPageBackground()
        .navigationTitle(output?.kind.titleLabel ?? "Çalışma")
        .task {
            await workspaceStore.loadWorkspace()
            isLoading = false
        }
    }

    private var medicalDisclaimer: some View {
        HStack(spacing: SBSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .sbScaledFont(size: 13, weight: .semibold)
                .foregroundStyle(SBColors.blue)
                .accessibilityHidden(true)
            Text("Bu çalışma notu seçili kaynaktan hazırlandı. Sınav ve klinik kararlar için güncel kılavuz/ders kitabıyla doğrula.")
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SBSpacing.lg)
        .padding(.vertical, SBSpacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(SBColors.softLine).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Uyarı: çalışma notunu güvenilir kaynakla doğrula.")
    }

    @ViewBuilder
    private func studySurface(for output: GeneratedOutput) -> some View {
        switch output.kind {
        case .flashcard:
            FlashcardStudySurface(output: output)
        case .question:
            QuestionStudySurface(output: output)
        case .podcast:
            PodcastStudySurface(output: output)
        case .infographic:
            InfographicStudySurface(output: output)
        default:
            StudyDocumentSurface(output: output)
        }
    }
}

private struct FlashcardStudySurface: View {
    let output: GeneratedOutput

    @State private var deck: [SBFlashcard] = []
    @State private var flipped = false
    @State private var knownCount = 0
    @State private var totalCount = 0
    @State private var didLoad = false

    private var current: SBFlashcard? { deck.first }
    private var completed: Bool { didLoad && deck.isEmpty && totalCount > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                studyHeader(
                    title: output.title,
                    subtitle: totalCount == 0 ? "Kartlar bekleniyor" : "\(knownCount) / \(totalCount) öğrenildi • \(deck.count) kaldı",
                    icon: "rectangle.on.rectangle",
                    tint: SBColors.blue
                )

                if let current {
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            flipped.toggle()
                        }
                    } label: {
                        SBCard(radius: 18, borderColor: SBColors.blue.opacity(0.18)) {
                            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                                HStack {
                                    Text(flipped ? "Cevap" : "Soru")
                                        .font(SBTypography.caption)
                                        .foregroundStyle(SBColors.blue)
                                    Spacer()
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(SBColors.blue)
                                }

                                Text(flipped ? current.back : current.front)
                                    .font(SBTypography.heading3)
                                    .foregroundStyle(SBColors.navy)
                                    .fixedSize(horizontal: false, vertical: true)

                                if flipped && !current.explanation.isEmpty {
                                    Divider()
                                    Text(current.explanation)
                                        .font(SBTypography.bodyMedium)
                                        .foregroundStyle(SBColors.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else if !flipped && !current.hint.isEmpty {
                                    Text(current.hint)
                                        .font(SBTypography.bodySmall)
                                        .foregroundStyle(SBColors.muted)
                                }
                            }
                            .frame(minHeight: 260, alignment: .top)
                        }
                    }
                    .buttonStyle(PressableCardStyle())

                    HStack(spacing: SBSpacing.sm) {
                        SBButton("Tekrar", icon: "arrow.counterclockwise", variant: .secondary, fullWidth: true) {
                            requeue()
                        }
                        SBButton("Biliyorum", icon: "checkmark", fullWidth: true) {
                            markKnown()
                        }
                    }
                } else if completed {
                    SBEmptyState(
                        icon: "checkmark.seal.fill",
                        title: "Seti tamamladın",
                        message: "\(totalCount) kartın hepsini öğrendin olarak işaretledin. Tazelemek için baştan başlayabilirsin.",
                        badges: ["Flashcard"],
                        actionLabel: "Baştan Başla",
                        onAction: { resetDeck() }
                    )
                } else {
                    SBEmptyState(
                        icon: "rectangle.stack.badge.exclamationmark",
                        title: "Kart bulunamadı",
                        message: "Bu çıktı kart çalışma ekranı için hazır görünmüyor. Kaynağı yeniden üretmeyi deneyebilirsin.",
                        badges: ["Flashcard"]
                    )
                }

                if totalCount > 0 && !completed {
                    SBNotice(
                        icon: "arrow.counterclockwise.circle",
                        message: "“Tekrar” dediğin kartlar bilene kadar destenin sonuna eklenir.",
                        tint: SBColors.blue
                    )
                }

                SBPdfExportControls(output: output)
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .onAppear {
            if !didLoad { resetDeck() }
        }
    }

    private func resetDeck() {
        deck = output.flashcards
        totalCount = deck.count
        knownCount = 0
        flipped = false
        didLoad = true
    }

    private func markKnown() {
        flipped = false
        guard !deck.isEmpty else { return }
        deck.removeFirst()
        knownCount = min(totalCount, knownCount + 1)
    }

    private func requeue() {
        flipped = false
        guard deck.count > 1 else { return } // single remaining card stays put
        let card = deck.removeFirst()
        deck.append(card)
    }
}

private struct QuestionStudySurface: View {
    let output: GeneratedOutput

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var index = 0
    @State private var selectedIndex: Int?
    @State private var questions: [SBQuestionPrompt] = []
    @State private var feedbackByQuestion: [String: SBQuestionAnswerFeedback] = [:]
    @State private var isLoadingSession = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var questionStartedAt = Date()

    private var current: SBQuestionPrompt? {
        guard questions.indices.contains(index) else { return nil }
        return questions[index]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                studyHeader(
                    title: output.title,
                    subtitle: isLoadingSession ? "Soru oturumu hazırlanıyor" : "\(index + 1) / \(max(questions.count, 1)) soru",
                    icon: "questionmark.circle",
                    tint: SBColors.cyan
                )

                if isLoadingSession {
                    SBLoadingState(
                        icon: "questionmark.circle",
                        title: "Soru çözümü hazırlanıyor",
                        message: "Sorular cevap anahtarı gösterilmeden yükleniyor..."
                    )
                } else if let errorMessage {
                    SBErrorState(
                        title: "Soru oturumu açılamadı",
                        message: errorMessage,
                        actionLabel: "Tekrar Dene",
                        onAction: { Task { await loadSession() } }
                    )
                } else if let question = current {
                    SBCard(radius: 18) {
                        VStack(alignment: .leading, spacing: SBSpacing.md) {
                            FlowLayout(spacing: SBSpacing.xs) {
                                tag(question.subject)
                                tag(question.topic)
                                tag(question.difficulty.capitalized)
                            }

                            Text(question.text)
                                .font(SBTypography.heading3)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(spacing: SBSpacing.sm) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                            optionButton(question: question, option: option, optionIndex: optionIndex)
                        }
                    }

                    if let feedback = feedbackByQuestion[question.id] {
                        resultCard(feedback: feedback)
                        SBButton(index + 1 == questions.count ? "Çalışmayı Bitir" : "Sonraki Soru", icon: "arrow.right", fullWidth: true) {
                            if index + 1 == questions.count {
                                appState.router.replaceCurrent(with: .collections)
                            } else {
                                selectedIndex = nil
                                questionStartedAt = Date()
                                index = min(index + 1, questions.count - 1)
                            }
                        }
                    } else if let selectedIndex {
                        SBButton("Yanıtı gönder", icon: "checkmark.circle", isLoading: isSubmitting, fullWidth: true) {
                            Task { await submit(question: question, selectedIndex: selectedIndex) }
                        }
                    }
                } else {
                    SBErrorState(
                        title: "Soru seti çalışma formatında değil",
                        message: "Bu üretim 5 şıklı çözüm ekranı için hazır dönmedi. Kaynağı yeniden üretmeyi deneyebilirsin.",
                        actionLabel: nil,
                        onAction: nil
                    )
                }

                SBPdfExportControls(output: output)
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .task {
            await loadSession()
        }
    }

    private func optionButton(question: SBQuestionPrompt, option: String, optionIndex: Int) -> some View {
        let feedback = feedbackByQuestion[question.id]
        let isAnswered = feedback != nil
        let isSelected = selectedIndex == optionIndex || feedback?.selectedIndex == optionIndex
        let isCorrect = isAnswered && feedback?.correctIndex == optionIndex
        let isWrongSelection = isAnswered && isSelected && feedback?.isCorrect == false

        return Button {
            guard !isAnswered else { return }
            selectedIndex = optionIndex
        } label: {
            HStack(alignment: .top, spacing: SBSpacing.md) {
                Text(String(UnicodeScalar(65 + optionIndex)!))
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(isCorrect || isWrongSelection ? .white : SBColors.blue)
                    .frame(width: 30, height: 30)
                    .background(isCorrect ? SBColors.green : isWrongSelection ? SBColors.red : SBColors.selectedBlue)
                    .clipShape(Circle())

                Text(option)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.navy)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(SBSpacing.md)
            .background(isCorrect ? SBColors.greenBg : isWrongSelection ? SBColors.red.opacity(0.08) : SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCorrect ? SBColors.green : isWrongSelection ? SBColors.red : SBColors.softLine, lineWidth: 1.2)
            )
        }
        .buttonStyle(PressableCardStyle())
        .disabled(isSubmitting)
    }

    private func resultCard(feedback: SBQuestionAnswerFeedback) -> some View {
        SBCard(radius: 16, borderColor: (feedback.isCorrect ? SBColors.green : SBColors.red).opacity(0.24)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                Text(resultTitle(feedback))
                    .font(SBTypography.titleSmall)
                    .foregroundStyle(feedback.isCorrect ? SBColors.green : SBColors.red)

                if !feedback.explanation.isEmpty {
                    Text(feedback.explanation)
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.navy)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(feedback.optionRationales.prefix(5).enumerated()), id: \.offset) { item in
                    Text("\(String(UnicodeScalar(65 + item.offset)!)) - \(item.element)")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func resultTitle(_ feedback: SBQuestionAnswerFeedback) -> String {
        if feedback.isCorrect {
            return "Doğru yanıt"
        }
        if let correctIndex = feedback.correctIndex,
           let letter = UnicodeScalar(65 + correctIndex) {
            return "Bu seçenek doğru değil. Doğru yanıt: \(String(letter))"
        }
        return "Bu seçenek doğru değil"
    }

    private func loadSession() async {
        isLoadingSession = true
        errorMessage = nil
        selectedIndex = nil
        feedbackByQuestion = [:]
        do {
            questions = try await workspaceStore.loadQuestionSession(outputId: output.id)
            if questions.isEmpty {
                errorMessage = "Bu soru seti çözüm ekranı için 5 şıklı formatta hazırlanmadı. Kaynağı yeniden üretmeyi deneyebilirsin."
            }
            index = 0
            questionStartedAt = Date()
        } catch {
            questions = []
            errorMessage = workspaceStore.friendlyError(error)
        }
        isLoadingSession = false
    }

    private func submit(question: SBQuestionPrompt, selectedIndex: Int) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        let elapsed = max(0, Int(Date().timeIntervalSince(questionStartedAt)))
        do {
            let feedback = try await workspaceStore.submitQuestionAnswer(
                outputId: output.id,
                questionId: question.id,
                selectedIndex: selectedIndex,
                elapsedSeconds: elapsed
            )
            feedbackByQuestion[question.id] = feedback
        } catch {
            errorMessage = workspaceStore.friendlyError(error)
        }
        isSubmitting = false
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(SBTypography.caption)
            .foregroundStyle(SBColors.blue)
            .padding(.horizontal, SBSpacing.sm)
            .padding(.vertical, SBSpacing.xs)
            .background(SBColors.selectedBlue)
            .clipShape(Capsule())
    }
}

// MARK: - Per-kind visual style (single source for screen + chrome)

enum SBOutputStyle {
    static func accent(for kind: GeneratedKind) -> Color {
        switch kind {
        case .flashcard: return SBColors.blue
        case .question: return SBColors.cyan
        case .summary: return SBColors.blue
        case .examMorningSummary: return SBColors.purple
        case .algorithm: return SBColors.green
        case .comparison, .table: return SBColors.orange
        case .clinicalScenario: return SBColors.red
        case .learningPlan: return SBColors.deepBlue
        case .podcast: return SBColors.purple
        case .infographic: return SBColors.cyan
        case .mindMap: return SBColors.blue
        }
    }

    static func icon(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard: return "rectangle.on.rectangle"
        case .question: return "checklist"
        case .summary: return "doc.text"
        case .examMorningSummary: return "alarm"
        case .algorithm: return "arrow.triangle.branch"
        case .comparison, .table: return "tablecells"
        case .clinicalScenario: return "stethoscope"
        case .learningPlan: return "calendar"
        case .podcast: return "waveform"
        case .infographic: return "photo.on.rectangle"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        }
    }

    /// Color + SF Symbol for a callout style.
    static func callout(_ style: SBCalloutStyle, accent: Color) -> (color: Color, icon: String) {
        switch style {
        case .plain: return (accent, "circle.fill")
        case .mustKnow: return (SBColors.blue, "star.fill")
        case .redFlag: return (SBColors.red, "exclamationmark.triangle.fill")
        case .tip: return (SBColors.green, "lightbulb.fill")
        case .confused: return (SBColors.orange, "arrow.triangle.2.circlepath")
        case .objective: return (SBColors.purple, "target")
        }
    }
}

private enum StudyWorkspaceLayer: String, CaseIterable, Identifiable {
    case all
    case learn
    case flow
    case check

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Tümü"
        case .learn: return "Öğren"
        case .flow: return "Akış"
        case .check: return "Kontrol"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .learn: return "book.closed"
        case .flow: return "arrow.triangle.branch"
        case .check: return "checklist"
        }
    }
}

// MARK: - Systematic, per-type study surface (blocks → SwiftUI)

private struct StudyDocumentSurface: View {
    let output: GeneratedOutput

    @State private var selectedLayer: StudyWorkspaceLayer = .all

    private var document: SBStudyDocument { output.studyDocument }
    private var accent: Color { SBOutputStyle.accent(for: output.kind) }
    private var visibleBlocks: [SBStudyBlock] {
        guard selectedLayer != .all else { return document.blocks }
        return document.blocks.filter { $0.workspaceLayer == selectedLayer }
    }
    private var activeRecallCount: Int {
        document.blocks.reduce(0) { $0 + $1.activeRecallCount }
    }
    private var flowCount: Int {
        document.blocks.filter { $0.workspaceLayer == .flow }.count
    }
    private var tableCount: Int {
        document.blocks.filter { if case .table = $0 { return true }; return false }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                studyHeader(
                    title: document.title,
                    subtitle: document.subtitle.isEmpty ? output.kind.titleLabel : document.subtitle,
                    icon: SBOutputStyle.icon(for: output.kind),
                    tint: accent
                )

                workspaceOverview
                layerPicker

                if !document.summary.isEmpty {
                    summaryPanel
                }

                if visibleBlocks.isEmpty {
                    SBEmptyState(
                        icon: selectedLayer.icon,
                        title: "\(selectedLayer.title) katmanı boş",
                        message: "Bu üretimde bu katmana ait özel blok yok. Tüm katmana dönerek içeriğin tamamını görebilirsin.",
                        badges: ["Çalışma", "Katman"]
                    )
                } else {
                    ForEach(visibleBlocks) { block in
                        blockView(block)
                    }
                }

                SBPdfExportControls(output: output)
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
    }

    private var workspaceOverview: some View {
        SBMetricRibbon(items: [
            .init(icon: "rectangle.stack", value: "\(max(document.blocks.count, 1))", label: "çalışma bloğu", tint: accent),
            .init(icon: "brain.head.profile", value: "\(activeRecallCount)", label: "aktif tekrar", tint: SBColors.green),
            .init(icon: "arrow.triangle.branch", value: "\(flowCount)", label: "akış/karar", tint: SBColors.orange),
            .init(icon: "tablecells", value: "\(tableCount)", label: "tablo", tint: SBColors.cyan)
        ])
    }

    private var layerPicker: some View {
        FlowLayout(spacing: SBSpacing.sm) {
            ForEach(StudyWorkspaceLayer.allCases) { layer in
                layerChip(layer)
            }
        }
    }

    private func layerChip(_ layer: StudyWorkspaceLayer) -> some View {
        let isSelected = selectedLayer == layer
        return Button {
            SBHaptics.selection()
            withAnimation(SBMotion.spring) {
                selectedLayer = layer
            }
        } label: {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: layer.icon)
                    .sbScaledFont(size: 12, weight: .semibold)
                Text(layer.title)
                    .font(SBTypography.labelSmall)
            }
            .foregroundStyle(isSelected ? .white : SBColors.navy)
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(isSelected ? accent : SBColors.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? accent : SBColors.softLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var summaryPanel: some View {
        SBCard(radius: 18, borderColor: accent.opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    SBIconTile(icon: "quote.bubble.fill", tint: accent, size: 38, radius: 11)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Çalışma Özeti")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Text(output.kind.titleLabel)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                    Spacer()
                }
                Text(document.summary)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.navy)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: SBStudyBlock) -> some View {
        switch block {
        case let .paragraph(_, text):
            paragraphPanel(text)
        case let .calloutList(_, title, items, style):
            calloutCard(title: title, items: items, style: style)
        case let .steps(_, title, items):
            stepsCard(title: title, items: items)
        case let .decisions(_, title, nodes):
            decisionsCard(title: title, nodes: nodes)
        case let .table(_, title, table):
            tableCard(title: title, table: table)
        case let .keyValues(_, title, pairs):
            keyValuesCard(title: title, pairs: pairs)
        case let .qa(_, title, pairs):
            qaCard(title: title, pairs: pairs)
        case let .timeline(_, title, entries):
            timelineCard(title: title, entries: entries)
        case let .mindBranches(_, title, branches):
            mindCard(title: title, branches: branches)
        case let .image(_, url, caption):
            imageBlock(url: url, caption: caption)
        case let .audio(_, _, segments):
            audioTranscriptCard(segments: segments)
        case let .cards(_, cards):
            cardsPreview(cards)
        case let .quiz(_, questions):
            quizPreview(questions)
        }
    }

    private func paragraphPanel(_ text: String) -> some View {
        SBCard(radius: 16, borderColor: accent.opacity(0.12)) {
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                sectionTitle("Kaynak Notu", icon: "text.alignleft", color: accent)
                Text(text)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.navy)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: SBSpacing.sm) {
            SBIconTile(icon: icon, tint: color, size: 30, radius: 9)
            Text(title)
                .font(SBTypography.titleSmall)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func calloutCard(title: String, items: [String], style: SBCalloutStyle) -> some View {
        let look = SBOutputStyle.callout(style, accent: accent)
        return SBCard(radius: 17, borderColor: look.color.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: look.icon, color: look.color)
                ForEach(Array(items.enumerated()), id: \.offset) { item in
                    HStack(alignment: .top, spacing: SBSpacing.sm) {
                        Text("\(item.offset + 1)")
                            .font(SBTypography.caption)
                            .foregroundStyle(look.color)
                            .frame(width: 24, height: 24)
                            .background(look.color.opacity(0.1))
                            .clipShape(Circle())
                        Text(item.element)
                            .font(SBTypography.bodyMedium)
                            .foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(SBSpacing.sm)
                    .background(SBColors.field.opacity(style == .plain ? 0.55 : 0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func stepsCard(title: String, items: [String]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "list.number", color: accent)
                ForEach(Array(items.enumerated()), id: \.offset) { item in
                    HStack(alignment: .top, spacing: SBSpacing.md) {
                        Text("\(item.offset + 1)")
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(accent)
                            .clipShape(Circle())
                        Text(item.element)
                            .font(SBTypography.bodyMedium)
                            .foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(SBSpacing.sm)
                    .background(SBColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func decisionsCard(title: String, nodes: [SBDecisionNode]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.22)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "arrow.triangle.branch", color: accent)
                ForEach(nodes) { node in
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(node.title)
                            .font(SBTypography.labelMedium)
                            .foregroundStyle(SBColors.navy)
                        if !node.detail.isEmpty {
                            Text(node.detail)
                                .font(SBTypography.bodySmall)
                                .foregroundStyle(SBColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: SBSpacing.sm) {
                            if !node.yes.isEmpty { branchPill("Evet → \(node.yes)", color: SBColors.green) }
                            if !node.no.isEmpty { branchPill("Hayır → \(node.no)", color: SBColors.red) }
                        }
                        ForEach(Array(node.substeps.enumerated()), id: \.offset) { sub in
                            HStack(alignment: .top, spacing: SBSpacing.xs) {
                                Circle().fill(accent.opacity(0.55)).frame(width: 5, height: 5).padding(.top, 7)
                                Text(sub.element)
                                    .font(SBTypography.bodySmall)
                                    .foregroundStyle(SBColors.navy)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.md)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.1), lineWidth: 1))
                }
            }
        }
    }

    private func branchPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(SBTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, SBSpacing.sm)
            .padding(.vertical, SBSpacing.xs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private func keyValuesCard(title: String, pairs: [SBKeyValue]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "person.text.rectangle", color: accent)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(pairs) { pair in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pair.key)
                                .font(SBTypography.caption)
                                .foregroundStyle(accent)
                            Text(pair.value)
                                .font(SBTypography.bodyMedium)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SBSpacing.sm)
                        .background(SBColors.field)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func qaCard(title: String, pairs: [SBQAPair]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "questionmark.bubble", color: accent)
                ForEach(Array(pairs.enumerated()), id: \.element.id) { item in
                    let pair = item.element
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        HStack(alignment: .top, spacing: SBSpacing.sm) {
                            Text("\(item.offset + 1)")
                                .font(SBTypography.caption)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(accent)
                                .clipShape(Circle())
                            Text(pair.question)
                                .font(SBTypography.labelMedium)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !pair.answer.isEmpty {
                            Text(pair.answer)
                                .font(SBTypography.bodyMedium)
                                .foregroundStyle(SBColors.green)
                        }
                        if !pair.explanation.isEmpty {
                            Text(pair.explanation)
                                .font(SBTypography.bodySmall)
                                .foregroundStyle(SBColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.sm)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func timelineCard(title: String, entries: [SBTimelineEntry]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "calendar", color: accent)
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        HStack {
                            Text(entry.title)
                                .font(SBTypography.labelMedium)
                                .foregroundStyle(SBColors.navy)
                            Spacer()
                            if !entry.meta.isEmpty {
                                Text(entry.meta)
                                    .font(SBTypography.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, SBSpacing.sm)
                                    .padding(.vertical, 2)
                                    .background(accent)
                                    .clipShape(Capsule())
                            }
                        }
                        ForEach(Array(entry.items.enumerated()), id: \.offset) { item in
                            Text("• \(item.element)")
                                .font(SBTypography.bodySmall)
                                .foregroundStyle(SBColors.navy)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.md)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func mindCard(title: String, branches: [SBMindBranch]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "point.3.connected.trianglepath.dotted", color: accent)
                ForEach(branches) { branch in
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(branch.label)
                            .font(SBTypography.labelMedium)
                            .foregroundStyle(accent)
                        ForEach(Array(branch.children.enumerated()), id: \.offset) { child in
                            Text("• \(child.element)")
                                .font(SBTypography.bodyMedium)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !branch.tags.isEmpty {
                            FlowLayout(spacing: SBSpacing.xs) {
                                ForEach(Array(branch.tags.enumerated()), id: \.offset) { tag in
                                    Text(tag.element)
                                        .font(SBTypography.caption)
                                        .foregroundStyle(SBColors.muted)
                                        .padding(.horizontal, SBSpacing.sm)
                                        .padding(.vertical, 2)
                                        .background(SBColors.field)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.md)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    @ViewBuilder
    private func imageBlock(url: URL?, caption: String) -> some View {
        if let url {
            SBCard(radius: 16) {
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    if !caption.isEmpty {
                        Text(caption)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                }
            }
        }
    }

    private func tableCard(title: String, table: SBStudyTable) -> some View {
        SBCard(radius: 17, borderColor: SBColors.orange.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle(title, icon: "tablecells", color: accent)
                ScrollView(.horizontal, showsIndicators: true) {
                    Grid(alignment: .leading, horizontalSpacing: SBSpacing.sm, verticalSpacing: SBSpacing.sm) {
                        if !table.headers.isEmpty {
                            GridRow {
                                ForEach(table.headers, id: \.self) { header in
                                    Text(header)
                                        .font(SBTypography.labelSmall)
                                        .foregroundStyle(.white)
                                        .padding(SBSpacing.sm)
                                        .frame(minWidth: 130, alignment: .leading)
                                        .background(accent)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { row in
                            GridRow {
                                ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
                                    Text(cell.element)
                                        .font(SBTypography.bodySmall)
                                        .foregroundStyle(SBColors.navy)
                                        .padding(SBSpacing.sm)
                                        .frame(minWidth: 130, alignment: .topLeading)
                                        .background(row.offset.isMultiple(of: 2) ? SBColors.field : SBColors.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func cardsPreview(_ cards: [SBFlashcard]) -> some View {
        SBCard(radius: 17, borderColor: SBColors.blue.opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle("Aktif Hatırlama Kartları", icon: "rectangle.on.rectangle", color: SBColors.blue)
                ForEach(Array(cards.prefix(6).enumerated()), id: \.element.id) { item in
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text("Kart \(item.offset + 1)")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.blue)
                        Text(item.element.front)
                            .font(SBTypography.labelMedium)
                            .foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        if !item.element.hint.isEmpty {
                            Text(item.element.hint)
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.sm)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func quizPreview(_ questions: [SBQlinikQuestion]) -> some View {
        SBCard(radius: 17, borderColor: SBColors.cyan.opacity(0.2)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle("Kontrol Soruları", icon: "checklist", color: SBColors.cyan)
                ForEach(Array(questions.prefix(5).enumerated()), id: \.element.id) { item in
                    VStack(alignment: .leading, spacing: SBSpacing.sm) {
                        Text("\(item.offset + 1). \(item.element.text)")
                            .font(SBTypography.labelMedium)
                            .foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        FlowLayout(spacing: SBSpacing.xs) {
                            ForEach(Array(item.element.options.enumerated()), id: \.offset) { opt in
                                Text("\(String(UnicodeScalar(65 + opt.offset)!))) \(opt.element)")
                                    .font(SBTypography.caption)
                                    .foregroundStyle(SBColors.muted)
                                    .padding(.horizontal, SBSpacing.sm)
                                    .padding(.vertical, SBSpacing.xs)
                                    .background(SBColors.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.sm)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func audioTranscriptCard(segments: [SBPodcastSegment]) -> some View {
        SBCard(radius: 17, borderColor: accent.opacity(0.18)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                sectionTitle("Anlatım Bölümleri", icon: "waveform", color: accent)
                ForEach(segments) { segment in
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(segment.title)
                            .font(SBTypography.labelMedium)
                            .foregroundStyle(SBColors.navy)
                        Text(segment.text)
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SBSpacing.sm)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

}

private extension SBStudyBlock {
    var workspaceLayer: StudyWorkspaceLayer {
        switch self {
        case .decisions, .steps, .timeline, .mindBranches:
            return .flow
        case .qa, .quiz, .cards:
            return .check
        case .paragraph, .calloutList, .table, .keyValues, .image, .audio:
            return .learn
        }
    }

    var activeRecallCount: Int {
        switch self {
        case let .cards(_, cards):
            return cards.count
        case let .quiz(_, questions):
            return questions.count
        case let .qa(_, _, pairs):
            return pairs.count
        case let .calloutList(_, _, items, style):
            switch style {
            case .mustKnow, .tip, .confused:
                return items.count
            case .plain, .redFlag, .objective:
                return 0
            }
        case .paragraph, .steps, .decisions, .table, .keyValues, .timeline, .mindBranches, .image, .audio:
            return 0
        }
    }
}

private struct PodcastStudySurface: View {
    let output: GeneratedOutput

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var speed: Float = 1
    @State private var progress: Double = 0
    @State private var timeObserver: Any?
    @State private var audioExportURL: URL?
    @State private var isExportingAudio = false
    @State private var audioExportMessage: String?

    private var content: SBPodcastContent { output.podcastContent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                studyHeader(title: content.title, subtitle: content.durationLabel.isEmpty ? "Medasi Podcast" : content.durationLabel, icon: "waveform", tint: SBColors.purple)

                SBMetricRibbon(items: [
                    .init(icon: "list.bullet.rectangle", value: "\(content.segments.count)", label: "bölüm", tint: SBColors.purple),
                    .init(icon: "timer", value: content.durationLabel.isEmpty ? "metin" : content.durationLabel, label: "süre", tint: SBColors.blue),
                    .init(icon: "speedometer", value: String(format: "%.2gx", Double(speed)), label: "oynatım", tint: SBColors.orange)
                ])

                SBCard(radius: 18, borderColor: SBColors.purple.opacity(0.2)) {
                    VStack(alignment: .leading, spacing: SBSpacing.lg) {
                        HStack(spacing: SBSpacing.md) {
                            Button {
                                togglePlayback()
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .sbScaledFont(size: 22, weight: .bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 54)
                                    .background(content.audioURL == nil ? SBColors.softLine : SBColors.purple)
                                    .clipShape(Circle())
                            }
                            .disabled(content.audioURL == nil)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(content.audioURL == nil ? "Sesli anlatım hazır değil" : "Sesli anlatım hazır")
                                    .font(SBTypography.titleSmall)
                                    .foregroundStyle(SBColors.navy)
                                Text(content.audioURL == nil ? "Aşağıdaki anlatım metnini okuyabilirsin." : "Medasi oynatıcı")
                                    .font(SBTypography.caption)
                                    .foregroundStyle(SBColors.muted)
                            }

                            Spacer()

                            Menu {
                                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { item in
                                    Button("\(item, specifier: "%.2g")x") {
                                        speed = Float(item)
                                        player?.rate = isPlaying ? speed : 0
                                    }
                                }
                            } label: {
                                Text("\(Double(speed), specifier: "%.2g")x")
                                    .font(SBTypography.labelSmall)
                                    .foregroundStyle(SBColors.purple)
                                    .padding(.horizontal, SBSpacing.sm)
                                    .padding(.vertical, SBSpacing.xs)
                                    .background(SBColors.purple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }

                        if content.audioURL != nil {
                            ProgressView(value: progress)
                                .tint(SBColors.purple)
                        }

                        audioExportControls
                    }
                }

                ForEach(Array(content.segments.enumerated()), id: \.element.id) { item in
                    let segment = item.element
                    SBCard(radius: 16, borderColor: SBColors.purple.opacity(0.14)) {
                        VStack(alignment: .leading, spacing: SBSpacing.sm) {
                            HStack(alignment: .top, spacing: SBSpacing.sm) {
                                Text("\(item.offset + 1)")
                                    .font(SBTypography.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(SBColors.purple)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(segment.title)
                                        .font(SBTypography.titleSmall)
                                        .foregroundStyle(SBColors.navy)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !segment.durationLabel.isEmpty {
                                        Text(segment.durationLabel)
                                            .font(SBTypography.caption)
                                            .foregroundStyle(SBColors.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            Text(segment.text)
                                .font(SBTypography.bodyMedium)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(SBSpacing.sm)
                                .background(SBColors.field)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                SBPdfExportControls(output: output)
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            if let timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
        }
    }

    private func setupPlayer() {
        guard player == nil, let url = content.audioURL else { return }
        let newPlayer = AVPlayer(url: url)
        // Real progress: poll the player clock 4×/sec and update the bar.
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let item = newPlayer.currentItem else { return }
            let duration = item.duration.seconds
            guard duration.isFinite, duration > 0 else { return }
            let current = time.seconds
            let nextProgress = min(max(current / duration, 0), 1)
            let shouldReset = nextProgress >= 0.999
            Task { @MainActor in
                progress = shouldReset ? 0 : nextProgress
                if shouldReset {
                    isPlaying = false
                    player?.seek(to: .zero)
                }
            }
        }
        player = newPlayer
    }

    private func togglePlayback() {
        guard let player else { return }
        isPlaying.toggle()
        if isPlaying {
            player.rate = speed
        } else {
            player.pause()
        }
    }

    @ViewBuilder
    private var audioExportControls: some View {
        if content.audioURL != nil {
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                SBButton(
                    isExportingAudio ? "Ses hazırlanıyor" : "Ses dosyası oluştur",
                    icon: isExportingAudio ? "hourglass" : "waveform.badge.plus",
                    variant: .secondary,
                    fullWidth: true
                ) {
                    prepareAudioExport()
                }
                .disabled(isExportingAudio)

                if let audioExportURL {
                    ShareLink(item: audioExportURL) {
                        shareLabel("Ses dosyasını paylaş")
                    }
                }

                if let audioExportMessage {
                    SBInlineError(message: audioExportMessage, isWarning: true)
                }
            }
        } else {
            SBNotice(
                icon: "waveform.badge.exclamationmark",
                message: "Ses dosyası henüz hazır değil. Transkript hazır; ses tamamlandığında buradan dışa aktarılacak.",
                tint: SBColors.purple
            )
        }
    }

    private func prepareAudioExport() {
        guard !isExportingAudio else { return }
        isExportingAudio = true
        audioExportMessage = nil
        Task {
            do {
                audioExportURL = try await SBStudyExportService.exportPodcastAudio(for: output)
            } catch {
                audioExportMessage = "Ses dosyası indirilemedi. Bağlantı hazır olunca tekrar dene."
            }
            isExportingAudio = false
        }
    }

    private func shareLabel(_ title: String) -> some View {
        Label(title, systemImage: "square.and.arrow.up")
            .font(SBTypography.labelMedium)
            .foregroundStyle(SBColors.purple)
            .frame(maxWidth: .infinity)
            .padding(SBSpacing.md)
            .background(SBColors.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfographicStudySurface: View {
    let output: GeneratedOutput

    @State private var imageExportURL: URL?
    @State private var isExportingImage = false
    @State private var imageExportMessage: String?

    private var content: SBInfographicContent { output.infographicContent }
    private var hasImage: Bool { content.imageURL != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                studyHeader(
                    title: content.title,
                    subtitle: hasImage ? "Paylaşılabilir Medasi infografik" : "Metin bloklarıyla güvenli infografik",
                    icon: "photo.on.rectangle",
                    tint: SBColors.cyan
                )

                SBMetricRibbon(items: [
                    .init(icon: hasImage ? "photo.fill" : "doc.richtext", value: hasImage ? "görsel" : "blok", label: "format", tint: SBColors.cyan),
                    .init(icon: "rectangle.stack", value: "\(max(content.blocks.count, 1))", label: "bilgi bloğu", tint: SBColors.blue),
                    .init(icon: "checkmark.seal", value: "PDF", label: "export", tint: SBColors.green)
                ])

                infographicCard
                if hasImage, !content.blocks.isEmpty {
                    studyBlocksCard
                }

                if content.imageURL != nil {
                    SBButton(
                        isExportingImage ? "Görsel hazırlanıyor" : "Görsel dosyası oluştur",
                        icon: isExportingImage ? "hourglass" : "photo.badge.arrow.down",
                        variant: .secondary,
                        fullWidth: true
                    ) {
                        prepareImageExport()
                    }
                    .disabled(isExportingImage)

                    if let imageExportURL {
                        ShareLink(item: imageExportURL) {
                            shareLabel("İnfografiği paylaş")
                        }
                    }

                    if let imageExportMessage {
                        SBInlineError(message: imageExportMessage, isWarning: true)
                    }
                } else {
                    SBNotice(
                        icon: "photo.badge.exclamationmark",
                        message: "Paylaşılabilir görsel henüz hazır değil. Görsel tamamlandığında buradan doğrudan paylaşılacak.",
                        tint: SBColors.cyan
                    )
                }

                SBPdfExportControls(output: output)
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
        }
    }

    private var studyBlocksCard: some View {
        SBCard(radius: 16, borderColor: SBColors.cyan.opacity(0.16)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    SBIconTile(icon: "checklist", tint: SBColors.cyan, size: 38, radius: 11)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hızlı tekrar")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Text("Görseldeki bilgiyi aktif hatırlama için aç.")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                }

                VStack(spacing: SBSpacing.sm) {
                    ForEach(Array(content.blocks.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: SBSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .sbScaledFont(size: 14, weight: .semibold)
                                .foregroundStyle(SBColors.cyan)
                                .padding(.top, 3)

                            Text(item.element)
                                .font(SBTypography.bodySmall)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SBSpacing.sm)
                        .background(SBColors.field)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var infographicCard: some View {
        SBCard(radius: 18, borderColor: SBColors.cyan.opacity(0.22)) {
            ZStack(alignment: .bottomTrailing) {
                if let url = content.imageURL {
                    remoteImage(url)
                } else {
                    fallbackInfographicBody(assetIssue: false)
                }

                watermark
            }
            .frame(maxWidth: .infinity)
            .background(SBColors.field)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func remoteImage(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                SBLoadingState(icon: "photo", title: "Görsel yükleniyor", message: "İnfografik hazırlanıyor...")
                    .padding(SBSpacing.lg)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(content.title)
            case .failure:
                fallbackInfographicBody(assetIssue: true)
            @unknown default:
                fallbackInfographicBody(assetIssue: true)
            }
        }
    }

    private func fallbackInfographicBody(assetIssue: Bool) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            HStack(spacing: SBSpacing.sm) {
                SBIconTile(icon: assetIssue ? "photo.badge.exclamationmark" : "text.rectangle", tint: SBColors.cyan, size: 38, radius: 11)
                VStack(alignment: .leading, spacing: 3) {
                    Text(assetIssue ? "Görsel bağlantısı yüklenemedi" : "Metin infografik")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                    Text(assetIssue ? "Aynı içerik metin bloklarıyla gösteriliyor." : "Görsel asset beklenmeden okunabilir çıktı.")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }
            }

            if content.blocks.isEmpty {
                SBInlineError(
                    message: "İnfografik içeriği boş döndü. Kaynağı yeniden üretmeyi deneyebilirsin.",
                    isWarning: true
                )
            } else {
                VStack(spacing: SBSpacing.sm) {
                    ForEach(Array(content.blocks.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: SBSpacing.sm) {
                            Text("\(item.offset + 1)")
                                .font(SBTypography.labelSmall)
                                .foregroundStyle(SBColors.cyan)
                                .frame(width: 26, height: 26)
                                .background(SBColors.cyan.opacity(0.12))
                                .clipShape(Circle())

                            Text(item.element)
                                .font(SBTypography.bodyMedium)
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(SBSpacing.sm)
                        .background(SBColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(SBSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var watermark: some View {
        Text("MEDASI")
            .sbScaledFont(size: 18, weight: .black)
            .foregroundStyle(SBColors.blue.opacity(0.22))
            .padding(SBSpacing.md)
            .accessibilityHidden(true)
    }

    private func shareLabel(_ title: String) -> some View {
        Label(title, systemImage: "square.and.arrow.up")
            .font(SBTypography.labelMedium)
            .foregroundStyle(SBColors.blue)
            .frame(maxWidth: .infinity)
            .padding(SBSpacing.md)
            .background(SBColors.selectedBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func prepareImageExport() {
        guard !isExportingImage else { return }
        isExportingImage = true
        imageExportMessage = nil
        Task {
            do {
                imageExportURL = try await SBStudyExportService.exportInfographicImage(for: output)
            } catch {
                imageExportMessage = "Görsel dosyası indirilemedi. PDF çıktısı hâlâ kullanılabilir."
            }
            isExportingImage = false
        }
    }
}

@MainActor
private func studyHeader(title: String, subtitle: String, icon: String, tint: Color) -> some View {
    SBGradientHero(icon: icon, title: title, message: subtitle, tint: tint) {
        EmptyView()
    } footer: {
        FlowLayout(spacing: SBSpacing.sm) {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: "checkmark.seal")
                Text("Çalışma ekranı")
            }
            .font(SBTypography.caption)
            .foregroundStyle(SBColors.navy)
            .padding(.horizontal, SBSpacing.sm)
            .padding(.vertical, SBSpacing.xs)
            .background(SBColors.white.opacity(0.8))
            .clipShape(Capsule())
        }
    }
}
