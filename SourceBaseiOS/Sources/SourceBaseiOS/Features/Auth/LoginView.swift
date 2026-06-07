import SwiftUI
import SourceBaseBackend

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var email = ""
    @State private var password = ""
    @State private var isSecureVisible = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    private var session: SessionStore { appState.session }
    private var router: AppRouter { appState.router }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !session.isLoading
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, isCompact ? SBSpacing.xxxl : 56)
                    .padding(.bottom, SBSpacing.xxl)

                loginPanel

                footerSection
                    .padding(.top, SBSpacing.xl)
            }
            .padding(.horizontal, isCompact ? SBSpacing.lg : SBSpacing.xxl)
            .padding(.bottom, 48)
            .sbReadableWidth(560)
        }
        .scrollIndicators(.hidden)
        .sbPageBackground()
        .navigationBarBackButtonHidden(true)
        .onChange(of: session.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                navigateAfterLogin()
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: SBSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SBColors.blue)
                    .frame(width: 64, height: 64)
                    .shadow(color: SBColors.blue.opacity(0.22), radius: 18, x: 0, y: 10)

                Image(systemName: "book.closed.fill")
                    .sbScaledFont(size: 28, weight: .semibold)
                    .foregroundStyle(.white)
            }

            VStack(spacing: SBSpacing.xs) {
                Text("SourceBase")
                    .font(SBTypography.heading1)
                    .foregroundStyle(SBColors.navy)
                    .multilineTextAlignment(.center)

                Text("Hesabına giriş yap")
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var loginPanel: some View {
        VStack(spacing: SBSpacing.lg) {
            VStack(spacing: SBSpacing.md) {
                fieldContainer(
                    icon: "envelope",
                    isFocused: focusedField == .email
                ) {
                    TextField("E-posta", text: $email)
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.navy)
                        .focused($focusedField, equals: .email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldContainer(
                    icon: "lock",
                    isFocused: focusedField == .password
                ) {
                    HStack(spacing: SBSpacing.sm) {
                        passwordInput

                        Button {
                            isSecureVisible.toggle()
                        } label: {
                            Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                                .sbScaledFont(size: 18, weight: .medium)
                                .foregroundStyle(SBColors.muted)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSecureVisible ? "Şifreyi gizle" : "Şifreyi göster")
                    }
                }
            }

            messageSection

            VStack(spacing: SBSpacing.md) {
                SBButton(
                    "Giriş yap",
                    icon: "arrow.right",
                    variant: .primary,
                    size: .large,
                    isLoading: session.isLoading,
                    fullWidth: true,
                    action: signIn
                )
                .disabled(!canSubmit)

                Button("Şifremi unuttum") {
                    router.navigate(to: .forgotPassword)
                }
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.blue)
                .frame(maxWidth: .infinity)
                .disabled(session.isLoading)
            }
        }
        .padding(SBSpacing.xl)
        .background(SBColors.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
        .shadow(color: SBColors.navy.opacity(0.075), radius: 22, x: 0, y: 12)
    }

    @ViewBuilder
    private var passwordInput: some View {
        Group {
            if isSecureVisible {
                TextField("Şifre", text: $password)
                    #if os(iOS)
                    .textContentType(.password)
                    #endif
            } else {
                SecureField("Şifre", text: $password)
                    #if os(iOS)
                    .textContentType(.password)
                    #endif
            }
        }
        .font(SBTypography.bodyMedium)
        .foregroundStyle(SBColors.navy)
        .focused($focusedField, equals: .password)
        .submitLabel(.go)
        .onSubmit { signIn() }
    }

    private func fieldContainer<Content: View>(
        icon: String,
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .semibold)
                .foregroundStyle(isFocused ? SBColors.blue : SBColors.muted)
                .frame(width: 24)

            content()
        }
        .padding(.horizontal, SBSpacing.lg)
        .frame(height: 56)
        .background(isFocused ? SBColors.fieldFocus : SBColors.field)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? SBColors.blue.opacity(0.7) : SBColors.line, lineWidth: isFocused ? 1.4 : 1)
        )
    }

    @ViewBuilder
    private var messageSection: some View {
        if let error = session.errorMessage {
            SBInlineError(message: error)
        }
        if let success = session.successMessage {
            HStack(spacing: SBSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SBColors.green)
                Text(success)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SBColors.greenBg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var footerSection: some View {
        HStack(spacing: 5) {
            Text("Hesabın yok mu?")
                .foregroundStyle(SBColors.muted)
            Button("Kayıt ol") {
                router.navigate(to: .register)
            }
            .font(SBTypography.labelMedium)
            .foregroundStyle(SBColors.blue)
        }
        .font(SBTypography.bodyMedium)
        .frame(maxWidth: .infinity)
        .disabled(session.isLoading)
    }

    private func signIn() {
        guard canSubmit else { return }
        focusedField = nil
        session.clearMessages()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let didSignIn = await session.signIn(email: cleanEmail, password: password)
            if didSignIn {
                navigateAfterLogin(email: cleanEmail)
            }
        }
    }

    private func navigateAfterLogin(email fallbackEmail: String? = nil) {
        if session.needsEmailVerification {
            router.replace(with: .verifyEmail(email: session.email.isEmpty ? fallbackEmail ?? email : session.email))
        } else if session.needsProfileSetup {
            router.replace(with: .profileSetup)
        } else {
            router.reset(to: .drive)
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState.shared)
}
