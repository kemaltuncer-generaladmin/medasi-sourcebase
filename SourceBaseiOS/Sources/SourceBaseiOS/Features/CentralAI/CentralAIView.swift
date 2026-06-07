import SwiftUI
import SourceBaseBackend

struct CentralAIView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isLoading = true

    private var router: AppRouter { appState.router }
    private var contextFiles: [DriveFile] {
        let selected = workspaceStore.selectedReadyFiles
        if !selected.isEmpty { return selected }
        if let file = workspaceStore.file(id: workspaceStore.selectedFileId), workspaceStore.isReadyForGeneration(file) {
            return [file]
        }
        return Array(workspaceStore.readyFiles.prefix(1))
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isAi: Bool
        let timestamp: Date = Date()
    }

    @FocusState private var isInputFocused: Bool

    private var hasSourceContext: Bool {
        !contextFiles.isEmpty
    }

    private var canSendMessage: Bool {
        hasSourceContext && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        Group {
            if isLoading {
                SBLoadingState(
                    icon: "text.bubble",
                    title: "MedasiChat yükleniyor",
                    message: "Sohbet hazırlanıyor..."
                )
            } else {
                messagesList
            }
        }
        .sbPageBackground()
        .safeAreaInset(edge: .bottom) {
            if !isLoading { inputArea }
        }
        .navigationTitle("MedasiChat")
        .sbOpaqueNavBar()
        .task { await loadMessages() }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: SBSpacing.md) {
                    contextHeader
                    suggestedPrompts

                    ForEach(messages) { message in
                        chatBubble(message)
                            .id(message.id)
                    }
                }
                .padding(SBSpacing.lg)
                .sbFloatingTabContentPadding(132)
                .sbReadableWidth(760)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isAi {
                HStack(alignment: .top, spacing: SBSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(SBColors.brandGradient)
                            .frame(width: 32, height: 32)

                        Image(systemName: "text.bubble.fill")
                            .sbScaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: SBColors.blue.opacity(0.25), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        Text(message.text)
                            .font(SBTypography.bodyMedium)
                            .foregroundStyle(SBColors.navy)
                            .lineSpacing(2)

                        Text(message.timestamp, style: .time)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.softText)
                    }
                    .padding(SBSpacing.md)
                    .background(SBColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SBColors.blue.opacity(0.12), lineWidth: 1)
                    )
                    .frame(maxWidth: 560, alignment: .leading)
                }

                Spacer(minLength: 40)
            } else {
                // User message (right)
                Spacer(minLength: 40)

                VStack(alignment: .trailing, spacing: SBSpacing.xs) {
                    Text(message.text)
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(.white)
                        .lineSpacing(2)

                    Text(message.timestamp, style: .time)
                        .font(SBTypography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(SBSpacing.md)
                .background(SBColors.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: SBColors.blue.opacity(0.22), radius: 8, x: 0, y: 4)
                .frame(maxWidth: 560, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.isAi ? "Asistan mesajı" : "Senin mesajın")
        .accessibilityValue(message.text)
    }

    private var contextHeader: some View {
        SBCard(radius: 18, borderColor: SBColors.blue.opacity(0.16)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kaynak bağlamı")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Text(contextFiles.isEmpty ? "Hazır kaynak seçilmedi" : "\(contextFiles.count) kaynak")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }

                    Spacer()

                    Button {
                        messages = [welcomeMessage()]
                    } label: {
                        Image(systemName: "plus.message")
                            .sbScaledFont(size: 18, weight: .semibold)
                            .foregroundStyle(SBColors.blue)
                            .frame(width: 38, height: 38)
                            .background(SBColors.selectedBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Yeni sohbet")
                    .accessibilityHint("Sohbet geçmişini temizleyip başlangıç mesajına döner")
                }

                if contextFiles.isEmpty {
                    SBButton("Kaynak seç", icon: "folder", variant: .secondary, size: .small) {
                        router.navigate(to: .sourcePicker)
                    }
                } else {
                    FlowLayout(spacing: SBSpacing.sm) {
                        ForEach(contextFiles) { file in
                            Button {
                                router.navigate(to: .fileDetail(fileId: file.id))
                            } label: {
                                HStack(spacing: SBSpacing.xs) {
                                    Image(systemName: "doc.text")
                                        .sbScaledFont(size: 12, weight: .semibold)
                                    Text(file.title)
                                        .font(SBTypography.caption)
                                        .lineLimit(1)
                                }
                                .foregroundStyle(SBColors.blue)
                                .padding(.horizontal, SBSpacing.sm)
                                .padding(.vertical, SBSpacing.xs)
                                .background(SBColors.selectedBlue)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Kaynak: \(file.title)")
                            .accessibilityHint("Kaynak detayını açar")
                        }
                    }
                }
            }
        }
    }

    private var suggestedPrompts: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Başlat")
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SBSpacing.sm) {
                    promptChip("Sınav özeti", icon: "sunrise.fill", tint: SBColors.orange)
                    promptChip("5 klinik soru", icon: "stethoscope", tint: SBColors.cyan)
                    promptChip("Tablo yap", icon: "tablecells", tint: SBColors.purple)
                }
                .padding(.bottom, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func promptChip(_ text: String, icon: String, tint: Color) -> some View {
        Button {
            sendText(text)
        } label: {
            HStack(spacing: SBSpacing.xs) {
                Image(systemName: icon)
                    .sbScaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(tint)
                Text(text)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.navy)
            }
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(SBColors.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isSending || !hasSourceContext)
        .accessibilityLabel(text)
        .accessibilityHint(hasSourceContext ? "Bu başlangıçla kaynak sohbetini aç" : "Önce hazır kaynak seç")
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: SBSpacing.md) {
                TextField(hasSourceContext ? "Kaynağınla ilgili soru yaz" : "Önce hazır kaynak seç", text: $inputText, axis: .vertical)
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSendMessage {
                            sendMessage()
                        }
                    }
                    .accessibilityLabel("Mesaj yaz")
                    .accessibilityHint("Mesaj metnini girin")
                    .padding(.horizontal, SBSpacing.md)
                    .padding(.vertical, SBSpacing.sm)
                    .background(SBColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(SBColors.softLine, lineWidth: 1)
                    )

                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(canSendMessage ? SBColors.blue : SBColors.softLine)
                            .frame(width: 40, height: 40)

                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .sbScaledFont(size: 18, weight: .semibold)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isSending ? "Gönderiliyor" : "Gönder")
                .accessibilityValue(isSending ? "Mesaj gönderiliyor" : (canSendMessage ? "Hazır" : "Mesaj boş"))
                .accessibilityHint("Mesajı gönderir")
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, SBSpacing.md)
            .padding(.top, SBSpacing.sm)
            .padding(.bottom, SBSpacing.md)
            .sbReadableWidth(760)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendText(text)
    }

    private func sendText(_ text: String) {
        guard hasSourceContext else {
            workspaceStore.toast("MedasiChat için önce hazır bir kaynak seç.")
            return
        }
        let userMessage = ChatMessage(text: text, isAi: false)
        messages.append(userMessage)
        inputText = ""
        isInputFocused = false // gönderince klavyeyi kapat

        isSending = true

        Task {
            let contextIds = contextFiles.map(\.id)
            let aiText: String
            do {
                aiText = try await workspaceStore.sendCentralAIMessage(
                    text,
                    fileIds: contextIds
                )
            } catch {
                aiText = workspaceStore.friendlyError(error)
            }
            let aiMessage = ChatMessage(text: aiText, isAi: true)
            messages.append(aiMessage)

            isSending = false
        }
    }

    private func loadMessages() async {
        isLoading = true
        await workspaceStore.loadWorkspace()

        messages = [welcomeMessage()]

        isLoading = false
    }

    private func welcomeMessage() -> ChatMessage {
        guard let context = contextFiles.first?.title else {
            return ChatMessage(
                text: "MedasiChat kaynaklarına göre yanıt verir. Önce Drive'dan hazır bir kaynak seç.",
                isAi: true
            )
        }
        return ChatMessage(
            text: "Merhaba. \(context) kaynağına göre özet, soru veya tablo isteyebilirsin.",
            isAi: true
        )
    }
}

#Preview {
    NavigationStack {
        CentralAIView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
