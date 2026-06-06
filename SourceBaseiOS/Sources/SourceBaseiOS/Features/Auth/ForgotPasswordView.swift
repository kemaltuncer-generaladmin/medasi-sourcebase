import SwiftUI
import SourceBaseBackend

struct ForgotPasswordView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var localError: String?
    @State private var isSent = false
    @FocusState private var isEmailFocused: Bool

    private var session: SessionStore { appState.session }
    private var router: AppRouter { appState.router }

    private var canSubmit: Bool {
        !email.isEmpty && email.contains("@") && !session.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.xl) {
                headerSection
                emailField
                infoBox
                messageSection
                actionButtons
            }
            .padding(SBSpacing.xl)
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(SBColors.muted)
                }
            }
        }
        .onChange(of: session.successMessage) { _, message in
            if message?.contains("gönderildi") == true {
                isSent = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(SBColors.selectedBlue)
                    .frame(width: 56, height: 56)
                Image(systemName: "key.fill")
                    .sbScaledFont(size: 24, weight: .medium)
                    .foregroundStyle(SBColors.blue)
            }

            Text("Şifreni yenile")
                .font(SBTypography.display2)
                .foregroundStyle(SBColors.navy)

            Text("Şifreni yenilemek için kayıtlı e-posta adresini gir.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
    }

    // MARK: - Email Field

    private var emailField: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "envelope")
                .sbScaledFont(size: 18, weight: .medium)
                .foregroundStyle(SBColors.blue)
                .frame(width: 24)

            TextField("E-posta", text: $email)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                .focused($isEmailFocused)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .submitLabel(.send)
                .accessibilityLabel("E-posta adresi")
                .onSubmit { sendReset() }
        }
        .padding(.horizontal, SBSpacing.lg)
        .frame(height: 52)
        .background(SBColors.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEmailFocused ? SBColors.blue : SBColors.line, lineWidth: isEmailFocused ? 1.5 : 1)
        )
        .shadow(color: SBColors.navy.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Info Box

    private var infoBox: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "info.circle")
                .sbScaledFont(size: 18)
                .foregroundStyle(SBColors.blue)

            Text("Bağlantı yalnızca kayıtlı e-posta adresine gönderilir.")
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColors.selectedBlue)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    // MARK: - Messages

    @ViewBuilder
    private var messageSection: some View {
        if let error = localError ?? session.errorMessage {
            SBInlineError(message: error)
        }
        if let success = session.successMessage {
            HStack(spacing: SBSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SBColors.green)
                Text(success)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.green)
            }
            .padding(SBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SBColors.greenBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: SBSpacing.md) {
            SBButton(
                session.isLoading ? "Gönderiliyor..." : "Sıfırlama bağlantısı gönder",
                icon: "paperplane",
                variant: .primary,
                size: .large,
                isLoading: session.isLoading,
                fullWidth: true,
                action: sendReset
            )
            .disabled(!canSubmit)

            SBButton(
                "Giriş ekranına dön",
                variant: .secondary,
                size: .medium,
                fullWidth: true,
                action: { router.popToRoot() }
            )
            .disabled(session.isLoading)
        }
    }

    // MARK: - Actions

    private func sendReset() {
        guard canSubmit else { return }

        if email.isEmpty {
            localError = "E-posta adresini girmelisin."
            return
        }
        if !email.contains("@") || !email.contains(".") {
            localError = "Geçerli bir e-posta adresi gir."
            return
        }

        localError = nil
        session.clearMessages()
        Task {
            await session.sendPasswordReset(email: email)
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environment(AppState.shared)
    }
}
