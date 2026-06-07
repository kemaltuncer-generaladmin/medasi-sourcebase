import SwiftUI
import SourceBaseBackend

/// Top-level scene content owned by the executable app target. Wires up
/// `AppState`, runs bootstrap, and hands off to routing. The app target's
/// `@main` only needs to embed this view inside a `WindowGroup`.
public struct SourceBaseRootView: View {
    @State private var appState = AppState.shared
    @State private var appearance = SBAppearancePreference.stored()

    public init() {}

    public var body: some View {
        RootView()
            .environment(appState)
            .environment(appState.workspace)
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .preferredColorScheme(appearance.colorScheme)
            .task {
                await appState.bootstrap()
                await setupStoreKitAfterFirstFrame()
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                appearance = SBAppearancePreference.stored()
            }
            .onOpenURL { url in
                Task {
                    await appState.handleOpenURL(url)
                }
            }
    }

    private func setupStoreKitAfterFirstFrame() async {
        SBStoreKitManager.shared.onRedeem = { txId, productId, jws in
            guard let client = await AuthBackend.shared.getClient() else {
                throw DriveAPIError(message: "IAP: oturum bulunamadı", code: nil, status: nil)
            }
            return try await DriveAPI(client: client).redeemAppStorePurchase(
                transactionId: txId,
                productId: productId,
                jws: jws
            )
        }

        await Task.yield()
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }

        SBStoreKitManager.shared.startListening()
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWarmLaunching = false

    var body: some View {
        Group {
            if !appState.isConfigured && appState.configError == nil {
                SBLoadingState(
                    icon: "hourglass",
                    title: "SourceBase",
                    message: "Uygulama başlatılıyor..."
                )
            } else if let error = appState.configError {
                SBErrorState(
                    icon: "exclamationmark.triangle",
                    title: "Yapılandırma Hatası",
                    message: error,
                    actionLabel: nil,
                    onAction: nil
                )
            } else if isWarmLaunching {
                WarmLaunchView()
                    .task {
                        try? await Task.sleep(nanoseconds: 950_000_000)
                        if reduceMotion {
                            isWarmLaunching = false
                        } else {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                                isWarmLaunching = false
                            }
                        }
                    }
            } else {
                MainNavigationView()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = appState.workspace.toastMessage {
                SBToast(message: toast)
                    .padding(.horizontal, SBSpacing.lg)
                    .padding(.bottom, SBSpacing.lg)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: appState.workspace.toastMessage)
        .onChange(of: appState.workspace.toastMessage) { _, message in
            guard message != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                if appState.workspace.toastMessage == message {
                    appState.workspace.toastMessage = nil
                }
            }
        }
    }
}

private struct SBToast: View {
    let message: String

    var body: some View {
        HStack(spacing: SBSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .sbScaledFont(size: 17, weight: .semibold)
                .foregroundStyle(SBColors.green)

            Text(message)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SBSpacing.md)
        .padding(.vertical, SBSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
        .shadow(color: SBColors.navy.opacity(0.16), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

struct MainNavigationView: View {
    @Environment(AppState.self) private var appState
    @State private var router = AppRouter.shared

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                switch appState.initialRoute {
                case .login:
                    LoginView()
                case .register:
                    RegisterView()
                case .verifyEmail(let email):
                    VerifyEmailView(email: email)
                case .profileSetup:
                    ProfileSetupView()
                case .forgotPassword:
                    ForgotPasswordView()
                default:
                    MainTabView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        // Auth
        case .login:
            LoginView()
        case .register:
            RegisterView()
        case .verifyEmail(let email):
            VerifyEmailView(email: email)
        case .profileSetup:
            ProfileSetupView()
        case .forgotPassword:
            ForgotPasswordView()
        case .resetPassword:
            ResetPasswordView()

        // Main tabs
        case .drive:
            DriveHomeView()
        case .baseForce:
            BaseForceHomeView()
        case .centralAI:
            CentralAIView()
        case .sourceLab:
            BaseForceHomeView()
        case .profile:
            ProfileView()

        // Drive sub-routes
        case .courseDetail(let courseId):
            CourseDetailView(courseId: courseId)
        case .folder(let courseId, let sectionId):
            FolderView(courseId: courseId, sectionId: sectionId)
        case .fileDetail(let fileId):
            FileDetailView(fileId: fileId)
        case .uploads:
            UploadsView()
        case .collections:
            CollectionsView()
        case .search:
            SearchView()

        // BaseForce sub-routes
        case .sourcePicker:
            SourcePickerView()
        case .flashcardFactory:
            FlashcardFactoryView()
        case .questionFactory:
            QuestionFactoryView()
        case .summaryFactory:
            SummaryFactoryView()
        case .algorithmFactory:
            AlgorithmFactoryView()
        case .comparisonFactory:
            ComparisonFactoryView()
        case .queue(let surface):
            QueueView(surface: surface)
        case .generationProcessing(let sourceFileId, let kind, let label, let surface, let mode, let options):
            GenerationProcessingView(
                sourceFileId: sourceFileId,
                kindRawValue: kind,
                label: label,
                surface: surface,
                mode: mode,
                extraOptions: options
            )
        case .result(let jobId):
            ResultView(jobId: jobId)
        case .studyOutput(let outputId):
            GeneratedOutputStudyView(outputId: outputId)

        // SourceLab sub-routes
        case .examMorning:
            ExamMorningView()
        case .clinical:
            ClinicalView()
        case .plan:
            PlanView()
        case .podcast:
            PodcastView()
        case .infographic:
            InfographicView()
        case .mindMap:
            MindMapView()

        // Profile sub-routes
        case .store:
            StoreView()
        case .settings:
            SettingsView()
        case .profileMenu(let destination):
            ProfileMenuDetailView(destination: destination)
        }
    }
}
