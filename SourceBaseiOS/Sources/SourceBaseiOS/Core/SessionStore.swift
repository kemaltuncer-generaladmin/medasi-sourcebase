import SwiftUI
import SourceBaseBackend
import Supabase

@Observable
@MainActor
public final class SessionStore {
    public static let shared = SessionStore()

    public private(set) var isInitialized = false
    public private(set) var initializationError: String?
    public private(set) var currentUser: User?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var successMessage: String?

    public var isLoggedIn: Bool {
        currentUser != nil
    }

    public var needsEmailVerification: Bool {
        guard let user = currentUser else { return false }
        return user.emailConfirmedAt == nil
    }

    public var needsProfileSetup: Bool {
        guard let user = currentUser else { return false }
        let metadata = user.userMetadata
        let faculty = metadata["sourcebase_faculty"]?.stringValue ?? ""
        let department = metadata["sourcebase_department"]?.stringValue ?? ""
        return faculty.trimmingCharacters(in: .whitespaces).isEmpty
            || department.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var displayName: String {
        guard let user = currentUser else { return "" }
        let metadata = user.userMetadata
        if let name = metadata["display_name"]?.stringValue, !name.isEmpty {
            return name
        }
        if let name = metadata["full_name"]?.stringValue, !name.isEmpty {
            return name
        }
        return user.email?.components(separatedBy: "@").first ?? "Kullanıcı"
    }

    public var email: String {
        currentUser?.email ?? ""
    }

    private init() {}

    // MARK: - Initialize

    public func initialize(config: SourceBaseConfig) async {
        guard !isInitialized else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await AuthBackend.shared.initialize(config: config)
            isInitialized = true
            currentUser = await AuthBackend.shared.currentUser()
            initializationError = nil
        } catch {
            initializationError = "Kimlik doğrulama yapılandırması başlatılamadı."
            errorMessage = initializationError
        }

        isLoading = false
    }

    // MARK: - Sign In

    @discardableResult
    public func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await withAuthTimeout {
                try await AuthBackend.shared.signIn(email: email, password: password)
            }
            if case .success(let message, let user) = result {
                let resolvedUser: User?
                if let user {
                    resolvedUser = user
                } else {
                    resolvedUser = await AuthBackend.shared.currentUser()
                }
                guard let resolvedUser else {
                    errorMessage = "Oturum açıldı ama kullanıcı bilgisi alınamadı. Lütfen tekrar dene."
                    return false
                }
                currentUser = resolvedUser
                successMessage = message
                return true
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        return false
    }

    // MARK: - Sign Up

    public func signUp(fullName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await AuthBackend.shared.signUp(
                fullName: fullName,
                email: email,
                password: password,
                profile: nil
            )
            if case .success(let message, _) = result {
                successMessage = message
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        isLoading = false
    }

    // MARK: - Verify Email OTP

    @discardableResult
    public func verifyEmailOTP(email: String, token: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await AuthBackend.shared.verifyEmailOTP(email: email, token: token)
            if case .success(let message, let user) = result {
                let resolvedUser: User?
                if let user {
                    resolvedUser = user
                } else {
                    resolvedUser = await AuthBackend.shared.currentUser()
                }
                guard let resolvedUser else {
                    errorMessage = "E-posta doğrulandı ama oturum bilgisi alınamadı. Lütfen tekrar giriş yap."
                    return false
                }
                currentUser = resolvedUser
                successMessage = message
                return true
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        return false
    }

    // MARK: - Resend Verification Email

    public func resendVerificationEmail(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await AuthBackend.shared.resendSignupEmail(email)
            if case .success(let message, _) = result {
                successMessage = message
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        isLoading = false
    }

    // MARK: - Update Profile

    public func updateProfile(
        faculty: String,
        department: String,
        classYear: String = "",
        goal: String = ""
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile = SourceBaseProfile(
                faculty: faculty,
                department: department,
                classYear: classYear,
                goal: goal
            )
            let result = try await AuthBackend.shared.updateSourceBaseProfile(profile)
            if case .success = result {
                currentUser = await AuthBackend.shared.currentUser()
                successMessage = "Profil bilgilerin tamamlandı."
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        isLoading = false
    }

    // MARK: - Password Reset

    public func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await AuthBackend.shared.sendPasswordReset(email)
            if case .success(let message, _) = result {
                successMessage = message
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        isLoading = false
    }

    public func updatePassword(_ password: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await AuthBackend.shared.updatePassword(password)
            if case .success(let message, _) = result {
                currentUser = await AuthBackend.shared.currentUser()
                successMessage = message
                isLoading = false
                return true
            }
        } catch {
            errorMessage = friendlyAuthError(error)
        }

        isLoading = false
        return false
    }

    // MARK: - Deep Links

    public func handleCallback(_ url: URL) async -> AuthCallbackResult? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await AuthBackend.shared.handleCallback(url)
            currentUser = await AuthBackend.shared.currentUser()
            successMessage = result.isPasswordRecovery
                ? "Yeni şifreni belirleyebilirsin."
                : "Oturum doğrulandı."
            isLoading = false
            return result
        } catch {
            errorMessage = friendlyAuthError(error)
            isLoading = false
            return nil
        }
    }

    // MARK: - Sign Out

    public func signOut() async {
        isLoading = true

        do {
            try await AuthBackend.shared.signOut()
            currentUser = nil
            successMessage = "Oturum kapatıldı."
        } catch {
            errorMessage = "Oturum kapatılamadı. Lütfen tekrar dene."
        }

        isLoading = false
    }

    // MARK: - Clear Messages

    public func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Error Handling

    private func friendlyAuthError(_ error: Error) -> String {
        let text = error.localizedDescription.lowercased()

        if text.contains("invalid login") || text.contains("invalid credentials") {
            return "E-posta veya şifre hatalı."
        }
        if text.contains("email not confirmed") {
            return "E-postanı doğruladıktan sonra giriş yapabilirsin."
        }
        if text.contains("already registered") || text.contains("user already exists") {
            return "Bu e-posta ile zaten bir hesap var."
        }
        if text.contains("weak password") {
            return "Şifre daha güçlü olmalı. En az 8 karakter kullan."
        }
        if text.contains("rate limit") || text.contains("too many") {
            return "Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar dene."
        }
        if text.contains("not configured") {
            return "Kimlik doğrulama yapılandırması eksik. Lütfen daha sonra tekrar dene."
        }
        if text.contains("network") || text.contains("connection") {
            return "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene."
        }
        if text.contains("timeout") || text.contains("timed out") {
            return "Giriş çok uzun sürdü. İnternetini kontrol edip tekrar dene."
        }

        return "İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar dene."
    }
}

private struct AuthTimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        "auth timeout"
    }
}

private func withAuthTimeout<T: Sendable>(
    seconds: UInt64 = 45,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw AuthTimeoutError()
        }
        guard let result = try await group.next() else {
            throw AuthTimeoutError()
        }
        group.cancelAll()
        return result
    }
}
