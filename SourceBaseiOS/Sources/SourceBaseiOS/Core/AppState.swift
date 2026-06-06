import SwiftUI
import SourceBaseBackend

@Observable
@MainActor
public final class AppState {
    public static let shared = AppState()

    public let session = SessionStore.shared
    public let router = AppRouter.shared
    public let workspace = SourceBaseWorkspaceStore.shared

    public var isConfigured = false
    public var configError: String?

    private init() {}

    // MARK: - Bootstrap

    public func bootstrap() async {
        let config = SourceBaseConfig.fromEnvironment()

        guard config.isConfigured else {
            configError = "SourceBase yapılandırması eksik."
            isConfigured = false
            return
        }

        await session.initialize(config: config)
        isConfigured = session.isInitialized

        if !isConfigured {
            configError = session.initializationError ?? "SourceBase başlatılamadı."
            return
        }

        if !session.isLoggedIn {
            router.reset(to: .login)
        }
    }

    // MARK: - Initial Route

    public var initialRoute: AppRoute {
        if !isConfigured {
            return .login
        }
        if !session.isLoggedIn {
            return .login
        }
        if session.needsEmailVerification {
            return .verifyEmail(email: session.email)
        }
        if session.needsProfileSetup {
            return .profileSetup
        }
        return .drive
    }

    // MARK: - Deep Links

    public func handleOpenURL(_ url: URL) async {
        guard url.scheme?.lowercased() == "sourcebase",
              url.host?.lowercased() == "auth",
              url.path.lowercased() == "/callback",
              isConfigured else {
            return
        }

        guard let result = await session.handleCallback(url) else {
            return
        }

        if result.isPasswordRecovery {
            router.replace(with: .resetPassword)
        } else if session.needsEmailVerification {
            router.replace(with: .verifyEmail(email: session.email))
        } else if session.needsProfileSetup {
            router.replace(with: .profileSetup)
        } else {
            router.reset(to: .drive)
        }
    }

    // MARK: - Sign Out

    public func signOut() async {
        await session.signOut()
        router.reset(to: .login)
    }
}
