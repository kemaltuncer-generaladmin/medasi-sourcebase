# SourceBase App Store Distribution

This app is now prepared for App Store distribution, not an internal-only TestFlight pass.

## Required Local Gates

Run these before upload:

```sh
swift test --package-path SourceBaseBackend
swift test --package-path SourceBaseiOS
xcodebuild -project App/SourceBase.xcodeproj -scheme SourceBase -configuration Release -destination 'generic/platform=iOS' archive -archivePath App/build/SourceBase-1.0.0-45.xcarchive
```

## Export / Upload

Use `App/ExportOptionsAppStoreConnect.plist`.

The export options are configured for App Store Connect upload, automatic signing, team `489N9D2VTC`, symbol upload, and non-internal distribution.

## App Store Review Checklist

- Bundle ID: `tr.com.medasi.sourcebase`
- Version: `1.0.0`
- Build: `45`
- Privacy manifest: `App/SourceBase/PrivacyInfo.xcprivacy`
- Entitlements: `App/SourceBase/SourceBase.entitlements`
- Encryption declaration: `ITSAppUsesNonExemptEncryption = false`
- Store purchase errors use user-facing App Store copy.
- Debug/TestFlight wording must not appear in release UI.
