import SwiftUI
import SourceBaseBackend

struct VerifyEmailView: View {
    let email: String

    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var otpCode: [String] = Array(repeating: "", count: 6)
    @State private var deadline = Date().addingTimeInterval(120)
    @State private var remainingSeconds = 120
    @State private var localError: String?
    @FocusState private var focusedIndex: Int?

    private static let resendInterval: TimeInterval = 120

    private var session: SessionStore { appState.session }
    private var router: AppRouter { appState.router }

    private var canVerify: Bool {
        otpCode.allSatisfy { !$0.isEmpty } && !session.isLoading
    }

    private var canResend: Bool {
        remainingSeconds == 0 && !session.isLoading
    }

    private var timerLabel: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.xl) {
                headerSection
                emailDisplay
                otpSection
                resendSection
                messageSection
                verifyButton
                footerLink
            }
            .padding(SBSpacing.xl)
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startTimer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshRemaining() }
        }
        .onChange(of: session.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn && !session.needsEmailVerification {
                navigateAfterVerification()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("E-postanı doğrula")
                .font(SBTypography.display2)
                .foregroundStyle(SBColors.navy)

            Text("E-posta adresini doğrulayarak hesabını güvenli hale getir.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
    }

    // MARK: - Email Display

    private var emailDisplay: some View {
        Text(email)
            .font(SBTypography.titleLarge)
            .foregroundStyle(SBColors.navy)
            .lineLimit(2)
    }

    // MARK: - OTP Section

    private var otpSection: some View {
        HStack(spacing: SBSpacing.sm) {
            ForEach(0..<6, id: \.self) { index in
                otpField(index: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func otpField(index: Int) -> some View {
        TextField("", text: $otpCode[index])
            .sbScaledFont(size: 24, weight: .bold)
            .foregroundStyle(SBColors.blue)
            .multilineTextAlignment(.center)
            #if os(iOS)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            #endif
            .frame(minWidth: 40, maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .background(SBColors.white.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focusedIndex == index ? SBColors.blue : SBColors.line, lineWidth: focusedIndex == index ? 2 : 1)
            )
            .focused($focusedIndex, equals: index)
            .accessibilityLabel("Doğrulama kodu hane \(index + 1)")
            .onChange(of: otpCode[index]) { _, newValue in
                // Keep a single digit; auto-advance and support paste-fill.
                let digits = newValue.filter(\.isNumber)
                if digits.count > 1 {
                    distribute(digits, startingAt: index)
                } else if digits != newValue {
                    otpCode[index] = String(digits.prefix(1))
                }
                if !otpCode[index].isEmpty && index < 5 {
                    focusedIndex = index + 1
                }
            }
    }

    // MARK: - Resend Section

    private var resendSection: some View {
        HStack {
            Text("Kod gelmedi mi?")
                .foregroundStyle(SBColors.muted)

            Spacer()

            Button {
                resendCode()
            } label: {
                Text(session.isLoading ? "Gönderiliyor..." : "Tekrar gönder")
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(canResend ? SBColors.blue : SBColors.muted)
            }
            .disabled(!canResend)

            Divider()
                .frame(height: 20)
                .padding(.horizontal, SBSpacing.sm)

            Text(timerLabel)
                .font(SBTypography.labelMedium)
                .foregroundStyle(canResend ? SBColors.blue : SBColors.muted)
        }
        .padding(SBSpacing.md)
        .background(SBColors.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SBColors.line, lineWidth: 1)
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

    // MARK: - Verify Button

    private var verifyButton: some View {
        SBButton(
            session.isLoading ? "Doğrulanıyor..." : "Doğrula",
            icon: "checkmark.shield",
            variant: .primary,
            size: .large,
            isLoading: session.isLoading,
            fullWidth: true,
            action: verify
        )
        .disabled(!canVerify)
    }

    // MARK: - Footer

    private var footerLink: some View {
        Button {
            router.replace(with: .register)
        } label: {
            Text("E-postayı değiştir")
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SBSpacing.sm)
    }

    // MARK: - Actions

    private func verify() {
        guard canVerify else { return }

        let code = otpCode.joined()
        if code.count != 6 {
            localError = "Lütfen 6 haneli doğrulama kodunu gir."
            return
        }

        localError = nil
        session.clearMessages()
        Task {
            let didVerify = await session.verifyEmailOTP(email: email, token: code)
            if didVerify {
                navigateAfterVerification()
            }
        }
    }

    private func resendCode() {
        guard canResend else { return }

        localError = nil
        session.clearMessages()
        Task {
            await session.resendVerificationEmail(email: email)
            startTimer()
        }
    }

    private func startTimer() {
        deadline = Date().addingTimeInterval(Self.resendInterval)
        refreshRemaining()
        Task {
            // Wall-clock based: recompute against `deadline` so backgrounding doesn't drift.
            while remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                refreshRemaining()
            }
        }
    }

    private func refreshRemaining() {
        remainingSeconds = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
    }

    /// Fill OTP boxes from a multi-digit string (e.g. autofill/paste).
    private func distribute(_ digits: String, startingAt index: Int) {
        var cursor = index
        for char in digits where cursor < 6 {
            otpCode[cursor] = String(char)
            cursor += 1
        }
        focusedIndex = min(cursor, 5)
    }

    private func navigateAfterVerification() {
        if session.needsProfileSetup {
            router.replace(with: .profileSetup)
        } else {
            router.reset(to: .drive)
        }
    }
}

#Preview {
    VerifyEmailView(email: "test@example.com")
        .environment(AppState.shared)
}
