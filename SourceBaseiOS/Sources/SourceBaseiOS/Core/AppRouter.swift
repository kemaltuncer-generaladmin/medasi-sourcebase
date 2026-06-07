import SwiftUI

public enum SourceBaseQueueSurface: Hashable, Sendable {
    case all
    case baseForce
    case sourceLab
}

public enum AppRoute: Hashable {
    // Auth
    case login
    case register
    case verifyEmail(email: String)
    case profileSetup
    case forgotPassword
    case resetPassword

    // Main tabs
    case drive
    case baseForce
    case centralAI
    case sourceLab
    case profile

    // Drive sub-routes
    case courseDetail(courseId: String)
    case folder(courseId: String, sectionId: String)
    case fileDetail(fileId: String)
    case uploads
    case collections
    case search

    // BaseForce sub-routes
    case sourcePicker
    case flashcardFactory
    case questionFactory
    case summaryFactory
    case algorithmFactory
    case comparisonFactory
    case queue(surface: SourceBaseQueueSurface = .all)
    case generationProcessing(sourceFileId: String, kind: String, label: String, surface: String, mode: String, options: [String: String] = [:])
    case result(jobId: String)
    case studyOutput(outputId: String)

    // SourceLab sub-routes
    case examMorning
    case clinical
    case plan
    case podcast
    case infographic
    case mindMap

    // Profile sub-routes
    case store
    case settings
    case profileMenu(ProfileMenuDestination)
}

public enum SourcePickerDestination: Hashable {
    case baseForceHome
    case sourceLabHome
    case route(AppRoute)
}

@Observable
@MainActor
public final class AppRouter {
    public static let shared = AppRouter()

    public var path: [AppRoute] = []
    public var selectedTab: AppRoute = .drive
    public var sourcePickerDestination: SourcePickerDestination?
    public var canPop: Bool { !path.isEmpty }

    private init() {}

    public func navigate(to route: AppRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path.removeAll()
    }

    public func replace(with route: AppRoute) {
        path.removeAll()
        path.append(route)
    }

    public func replaceCurrent(with route: AppRoute) {
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.count - 1] = route
        }
    }

    public func switchTab(to tab: AppRoute) {
        selectedTab = tab
        path.removeAll()
    }

    public func reset(to route: AppRoute) {
        path.removeAll()
        selectedTab = route
        sourcePickerDestination = nil
    }

    public func beginSourceSelection(from tab: AppRoute? = nil, destination: SourcePickerDestination) {
        if let tab {
            selectedTab = tab
            path.removeAll()
        }
        sourcePickerDestination = destination
        path.append(.sourcePicker)
    }

    public func completeSourceSelection() {
        let destination = sourcePickerDestination
        sourcePickerDestination = nil

        switch destination {
        case .baseForceHome:
            switchTab(to: .baseForce)
        case .sourceLabHome:
            switchTab(to: .sourceLab)
        case .route(let route):
            let tab = rootTab(for: route)
            selectedTab = tab
            path.removeAll()
            if route != tab {
                path.append(route)
            }
        case .none:
            if canPop {
                pop()
            } else {
                switchTab(to: .baseForce)
            }
        }
    }

    private func rootTab(for route: AppRoute) -> AppRoute {
        switch route {
        case .drive,
             .courseDetail,
             .folder,
             .fileDetail,
             .uploads,
             .collections,
             .search:
            return .drive
        case .baseForce,
             .sourcePicker,
             .flashcardFactory,
             .questionFactory,
             .summaryFactory,
             .algorithmFactory,
             .comparisonFactory,
             .queue,
             .generationProcessing,
             .result,
             .studyOutput:
            return .baseForce
        case .sourceLab,
             .examMorning,
             .clinical,
             .plan,
             .podcast,
             .infographic,
             .mindMap:
            return .sourceLab
        case .centralAI:
            return .centralAI
        case .profile,
             .store,
             .settings,
             .profileMenu:
            return .profile
        case .login,
             .register,
             .verifyEmail,
             .profileSetup,
             .forgotPassword,
             .resetPassword:
            return .drive
        }
    }
}
