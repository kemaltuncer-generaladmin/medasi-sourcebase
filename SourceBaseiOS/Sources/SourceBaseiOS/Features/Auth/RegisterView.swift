import SwiftUI
import SourceBaseBackend

struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var repeatPassword = ""
    @State private var termsAccepted = false
    @State private var isPasswordVisible = false
    @State private var isRepeatPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password, repeatPassword
    }

    @State private var localError: String?

    private var session: SessionStore { appState.session }
    private var router: AppRouter { appState.router }

    private var validationError: String? {
        if fullName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Ad soyad bilgisini doldurmalısın."
        }
        if email.isEmpty {
            return "E-posta adresini girmelisin."
        }
        if !email.contains("@") || !email.contains(".") {
            return "Geçerli bir e-posta adresi gir."
        }
        if password.count < 8 {
            return "Şifre en az 8 karakter olmalı."
        }
        if !password.contains(where: { $0.isLetter }) || !password.contains(where: { $0.isNumber }) {
            return "Şifre en az bir harf ve bir rakam içermeli."
        }
        if password != repeatPassword {
            return "Şifreler birbiriyle eşleşmiyor."
        }
        if !termsAccepted {
            return "Kullanım koşullarını kabul etmelisin."
        }
        return nil
    }

    private var canSubmit: Bool {
        validationError == nil && !session.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.xl) {
                headerSection.sbEntrance(0)
                formSection.sbEntrance(1)
                termsSection.sbEntrance(2)
                messageSection.sbEntrance(3)
                actionSection.sbEntrance(4)
                footerSection.sbEntrance(5)
            }
            .padding(SBSpacing.xl)
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .onChange(of: session.successMessage) { _, message in
            if message?.contains("Doğrulama") == true {
                router.replace(with: .verifyEmail(email: email))
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SBSignatureHero(
            eyebrow: "SourceBase üyeliği",
            title: "Hesap oluştur",
            message: "Kaynaklarını düzenlemek, üretmek ve çalışma akışını kişiselleştirmek için profilini başlat.",
            icon: "person.badge.plus.fill",
            tint: SBColors.purple
        ) {
            EmptyView()
        } footer: {
            SBMetricRibbon(items: [
                .init(icon: "checkmark.shield.fill", value: "Güvenli", label: "hesap akışı", tint: SBColors.green),
                .init(icon: "graduationcap.fill", value: "Tıp", label: "öğrenci profili", tint: SBColors.blue)
            ])
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: SBSpacing.md) {
            // Full Name
            formField(
                icon: "person",
                hint: "Ad Soyad",
                text: $fullName,
                isSecure: false,
                isVisible: .constant(true),
                focus: Field.name,
                onSubmit: { focusedField = .email }
            )

            // Email
            formField(
                icon: "envelope",
                hint: "E-posta",
                text: $email,
                isSecure: false,
                isVisible: .constant(true),
                focus: Field.email,
                isEmail: true,
                onSubmit: { focusedField = .password }
            )

            // Password
            formField(
                icon: "lock",
                hint: "Şifre",
                text: $password,
                isSecure: true,
                isVisible: $isPasswordVisible,
                focus: Field.password,
                isNewPassword: true,
                onSubmit: { focusedField = .repeatPassword }
            )

            // Repeat Password
            formField(
                icon: "lock",
                hint: "Şifre Tekrar",
                text: $repeatPassword,
                isSecure: true,
                isVisible: $isRepeatPasswordVisible,
                focus: Field.repeatPassword,
                isNewPassword: true,
                onSubmit: { signUp() }
            )
        }
    }

    private func formField(
        icon: String,
        hint: String,
        text: Binding<String>,
        isSecure: Bool,
        isVisible: Binding<Bool>,
        focus: Field,
        isEmail: Bool = false,
        isNewPassword: Bool = false,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .medium)
                .foregroundStyle(SBColors.blue)
                .frame(width: 24)
                .accessibilityHidden(true)

            Group {
                if isSecure && !isVisible.wrappedValue {
                    SecureField(hint, text: text)
                } else {
                    TextField(hint, text: text)
                }
            }
            .font(SBTypography.bodyMedium)
            .foregroundStyle(SBColors.navy)
            .focused($focusedField, equals: focus)
            #if os(iOS)
            .keyboardType(isEmail ? .emailAddress : .default)
            .textContentType(isEmail ? .emailAddress : isNewPassword ? .newPassword : isSecure ? .password : nil)
            .textInputAutocapitalization(isEmail || isSecure ? .never : .words)
            .autocorrectionDisabled(isEmail || isSecure)
            #endif
            .onSubmit(onSubmit)

            if isSecure {
                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .sbScaledFont(size: 18)
                        .foregroundStyle(SBColors.muted)
                }
                .accessibilityLabel(isVisible.wrappedValue ? "Şifreyi gizle" : "Şifreyi göster")
            }
        }
        .padding(.horizontal, SBSpacing.lg)
        .frame(height: 52)
        .background(SBColors.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == focus ? SBColors.blue : SBColors.line, lineWidth: focusedField == focus ? 1.5 : 1)
        )
        .shadow(color: SBColors.navy.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Terms

    private var termsSection: some View {
        HStack(alignment: .top, spacing: SBSpacing.md) {
            Button {
                termsAccepted.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(termsAccepted ? SBColors.blue : SBColors.white)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(SBColors.blue, lineWidth: 1.2)
                        )

                    if termsAccepted {
                        Image(systemName: "checkmark")
                            .sbScaledFont(size: 14, weight: .bold)
                            .foregroundStyle(.white)
                    }
                }
            }
            .accessibilityLabel(termsAccepted ? "Koşullar kabul edildi" : "Koşulları kabul et")

            VStack(alignment: .leading, spacing: 3) {
                Text("Devam ederek kabul ediyorum:")
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
                HStack(spacing: 4) {
                    Link("Kullanım Koşulları", destination: SBLegalLinks.termsURL)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.blue)
                    Text("ve")
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.navy)
                    Link("Gizlilik Politikası", destination: SBLegalLinks.privacyURL)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.blue)
                }
            }
        }
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

    private var actionSection: some View {
        VStack(spacing: SBSpacing.md) {
            SBButton(
                "Kayıt Ol",
                icon: "person.badge.plus",
                variant: .primary,
                size: .large,
                isLoading: session.isLoading,
                fullWidth: true,
                action: signUp
            )
            .disabled(!canSubmit)

            SBButton(
                "Giriş Yap",
                variant: .secondary,
                size: .large,
                fullWidth: true,
                action: { router.pop() }
            )
            .disabled(session.isLoading)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 4) {
            Text("Zaten hesabın var mı?")
                .foregroundStyle(SBColors.muted)
            Button("Giriş yap") {
                router.pop()
            }
            .font(SBTypography.labelMedium)
            .foregroundStyle(SBColors.blue)
        }
        .font(SBTypography.bodyMedium)
        .frame(maxWidth: .infinity)
        .padding(.top, SBSpacing.sm)
    }

    // MARK: - Actions

    private func signUp() {
        guard canSubmit else { return }

        if let error = validationError {
            localError = error
            return
        }

        localError = nil
        session.clearMessages()
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await session.signUp(fullName: cleanName, email: cleanEmail, password: password)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environment(AppState.shared)
    }
}
