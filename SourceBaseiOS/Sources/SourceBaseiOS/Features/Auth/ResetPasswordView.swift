import SwiftUI

struct ResetPasswordView: View {
    @Environment(AppState.self) private var appState
    @State private var password = ""
    @State private var confirmation = ""
    @State private var localError: String?

    private var session: SessionStore { appState.session }
    private var router: AppRouter { appState.router }

    private var canSubmit: Bool {
        password.count >= 8 && password == confirmation && !session.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.xl) {
                headerSection

                VStack(spacing: SBSpacing.md) {
                    passwordField(
                        icon: "lock",
                        hint: "Yeni şifre",
                        text: $password
                    )
                    passwordField(
                        icon: "lock.rotation",
                        hint: "Yeni şifre tekrar",
                        text: $confirmation,
                        onSubmit: updatePassword
                    )
                }

                messageSection

                SBButton(
                    "Şifreyi Güncelle",
                    icon: "checkmark",
                    variant: .primary,
                    size: .large,
                    isLoading: session.isLoading,
                    fullWidth: true,
                    action: updatePassword
                )
                .disabled(!canSubmit)
            }
            .padding(SBSpacing.xl)
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .navigationBarBackButtonHidden(true)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(SBColors.selectedBlue)
                    .frame(width: 56, height: 56)
                Image(systemName: "key.horizontal.fill")
                    .sbScaledFont(size: 24, weight: .medium)
                    .foregroundStyle(SBColors.blue)
            }

            Text("Yeni şifreni belirle")
                .font(SBTypography.display2)
                .foregroundStyle(SBColors.navy)

            Text("Hesabın için en az 8 karakterli yeni bir şifre oluştur.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
    }

    private func passwordField(
        icon: String,
        hint: String,
        text: Binding<String>,
        onSubmit: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .medium)
                .foregroundStyle(SBColors.blue)
                .frame(width: 24)

            SecureField(hint, text: text)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                #if os(iOS)
                .textContentType(.newPassword)
                #endif
                .accessibilityLabel(hint)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, SBSpacing.lg)
        .frame(height: 52)
        .background(SBColors.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SBColors.line, lineWidth: 1)
        )
        .shadow(color: SBColors.navy.opacity(0.05), radius: 8, x: 0, y: 4)
    }

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

    private func updatePassword() {
        guard !session.isLoading else { return }

        if password.count < 8 {
            localError = "Şifre en az 8 karakter olmalı."
            return
        }
        if password != confirmation {
            localError = "Şifreler eşleşmiyor."
            return
        }

        localError = nil
        session.clearMessages()
        Task {
            if await session.updatePassword(password) {
                router.reset(to: .drive)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResetPasswordView()
            .environment(AppState.shared)
    }
}
