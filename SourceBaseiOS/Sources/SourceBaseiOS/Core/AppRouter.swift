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

@Observable
@MainActor
public final class AppRouter {
    public static let shared = AppRouter()

    public var path: [AppRoute] = []
    public var selectedTab: AppRoute = .drive
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
    }
}
