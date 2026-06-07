import Foundation
import Testing

private var repositoryRoot: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url.deleteLastPathComponent()
    }
    return url
}

private func source(_ relativePath: String) throws -> String {
    try String(
        contentsOf: repositoryRoot.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

@Test func profileMenuNoticesDistinguishSuccessFromError() async throws {
    let profile = try source("SourceBaseiOS/Sources/SourceBaseiOS/Features/Profile/ProfileMenuDetailView.swift")

    #expect(profile.contains("private enum ProfileNotice"))
    #expect(profile.contains("case success(String)"))
    #expect(profile.contains("case error(String)"))
    #expect(profile.contains("return SBColors.green"))
    #expect(profile.contains("return SBColors.red"))
    #expect(profile.contains("notice = .success("))
    #expect(profile.contains("notice = .error("))
}

@Test func storeRestoreReportsSuccessAndFailureToUser() async throws {
    let store = try source("SourceBaseiOS/Sources/SourceBaseiOS/Features/Profile/StoreView.swift")

    #expect(store.contains("@State private var restoreNotice"))
    #expect(store.contains("if let restoreNotice"))
    #expect(store.contains("restoreNotice = .success("))
    #expect(store.contains("restoreNotice = .error("))
}

@Test func emailVerificationOtpFieldsUseFlexibleWidth() async throws {
    let verifyEmail = try source("SourceBaseiOS/Sources/SourceBaseiOS/Features/Auth/VerifyEmailView.swift")

    #expect(!verifyEmail.contains(".frame(width: 48, height: 56)"))
    #expect(verifyEmail.contains(".frame(minWidth: 40, maxWidth: .infinity, minHeight: 56, maxHeight: 56)"))
}

@Test func baseForceFactoryViewsUseSharedPanelStyle() async throws {
    let style = try source("SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/BaseForceFactoryStyle.swift")
    #expect(style.contains("static let panelRadius: CGFloat = 16"))
    #expect(style.contains("static let nestedPanelRadius: CGFloat = 14"))
    #expect(style.contains("static func panel<Content: View>"))

    let factoryFiles = [
        "SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/FlashcardFactoryView.swift",
        "SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/SummaryFactoryView.swift",
        "SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/AlgorithmFactoryView.swift",
        "SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/ComparisonFactoryView.swift"
    ]

    for factoryFile in factoryFiles {
        let contents = try source(factoryFile)
        #expect(contents.contains("BaseForceFactoryStyle.screenSpacing"))
        #expect(contents.contains("BaseForceFactoryStyle.pagePadding"))
        #expect(contents.contains("BaseForceFactoryStyle.panel"))
        #expect(!contents.contains("SBCard(radius: 16)"))
        #expect(!contents.contains("SBCard(radius: 14"))
    }
}
