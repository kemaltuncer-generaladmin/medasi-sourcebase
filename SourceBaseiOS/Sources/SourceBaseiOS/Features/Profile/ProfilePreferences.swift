import SwiftUI

enum SBProfilePreferenceKey {
    static let appearance = "sourcebase.profile.appearance"
    static let compactCards = "sourcebase.profile.compactCards"
    static let sourceNotifications = "sourcebase.profile.notifications.source"
    static let generationNotifications = "sourcebase.profile.notifications.generation"
    static let studyNotifications = "sourcebase.profile.notifications.study"
    static let analyticsSharing = "sourcebase.profile.privacy.analytics"
    static let demoFaculty = "sourcebase.profile.demo.faculty"
    static let demoDepartment = "sourcebase.profile.demo.department"
}

enum SBAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Açık"
        case .dark: return "Koyu"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func stored(in defaults: UserDefaults = .standard) -> SBAppearancePreference {
        guard let rawValue = defaults.string(forKey: SBProfilePreferenceKey.appearance) else {
            return .system
        }

        guard let preference = SBAppearancePreference(rawValue: rawValue) else {
            defaults.set(SBAppearancePreference.system.rawValue, forKey: SBProfilePreferenceKey.appearance)
            return .system
        }

        return preference
    }
}
