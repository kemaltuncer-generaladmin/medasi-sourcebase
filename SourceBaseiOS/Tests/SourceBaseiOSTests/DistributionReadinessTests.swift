import Foundation
import Testing

private var repositoryRoot: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url.deleteLastPathComponent()
    }
    return url
}

private func plist(at relativePath: String) throws -> [String: Any] {
    let data = try Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return try #require(object as? [String: Any])
}

@Test func appStoreExportOptionsTargetPublicDistribution() async throws {
    let options = try plist(at: "App/ExportOptionsAppStoreConnect.plist")

    #expect(options["method"] as? String == "app-store-connect")
    #expect(options["destination"] as? String == "upload")
    #expect(options["signingStyle"] as? String == "automatic")
    #expect(options["teamID"] as? String == "489N9D2VTC")
    #expect(options["testFlightInternalTestingOnly"] as? Bool == false)
    #expect(options["uploadSymbols"] as? Bool == true)
}

@Test func appPrivacyManifestIsPresentAndNonTracking() async throws {
    let manifest = try plist(at: "App/SourceBase/PrivacyInfo.xcprivacy")

    #expect(manifest["NSPrivacyTracking"] as? Bool == false)
    #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)

    let accessedTypes = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    let accessedCategories = Set(accessedTypes.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
    #expect(accessedCategories.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    #expect(accessedCategories.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))

    let collectedTypes = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
    let collectedCategories = Set(collectedTypes.compactMap { $0["NSPrivacyCollectedDataType"] as? String })
    #expect(collectedCategories.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    #expect(collectedCategories.contains("NSPrivacyCollectedDataTypeUserID"))
    #expect(collectedCategories.contains("NSPrivacyCollectedDataTypeOtherUserContent"))
    #expect(collectedCategories.contains("NSPrivacyCollectedDataTypePurchaseHistory"))
}

@Test func releaseProjectSettingsAreAppStoreReady() async throws {
    let info = try plist(at: "App/SourceBase/Info.plist")
    #expect(info["CFBundleDisplayName"] as? String == "SourceBase")
    #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)

    let project = try String(
        contentsOf: repositoryRoot.appendingPathComponent("App/SourceBase.xcodeproj/project.pbxproj"),
        encoding: .utf8
    )
    #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = tr.com.medasi.sourcebase;"))
    #expect(project.contains("MARKETING_VERSION = 1.0.0;"))
    #expect(project.contains("CURRENT_PROJECT_VERSION = 45;"))
    #expect(project.contains("CODE_SIGN_ENTITLEMENTS = SourceBase/SourceBase.entitlements;"))
    #expect(project.contains("PrivacyInfo.xcprivacy in Resources"))
}

@Test func releaseStoreCopyDoesNotExposeBetaOrSandboxLanguage() async throws {
    let storeView = try String(
        contentsOf: repositoryRoot.appendingPathComponent("SourceBaseiOS/Sources/SourceBaseiOS/Features/Profile/StoreView.swift"),
        encoding: .utf8
    )

    #expect(!storeView.contains("TestFlight"))
    #expect(!storeView.contains("Sandbox"))
    #expect(!storeView.contains("StoreKit config"))
}
