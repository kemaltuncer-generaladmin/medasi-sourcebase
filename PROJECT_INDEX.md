# SourceBase - Project Index

SourceBase is an iOS/SwiftUI study app backed by Supabase. The repo is split into a thin Xcode app shell and two local Swift packages.

Swift tools: 6.0  
Platforms: iOS 17, macOS 14  
Repo note: this checkout is not a git repository, so hotspot notes use file size and modified-time heuristics rather than commit history.

## Layout

- `App/SourceBase/` - Xcode app shell with the executable `@main`, `Info.plist`, launch/app assets, privacy manifest, and app entitlements.
- `SourceBaseiOS/` - UI and app-layer Swift package with `App`, `Core`, `DesignSystem`, and feature modules.
- `SourceBaseBackend/` - service/data Swift package with Supabase config, auth, drive/generation, and profile/store repositories.
- `docs/` - launch plan, backend contract, design-system notes, patch protocol, and agent guidance.

## Entry Points

- `App/SourceBase/SourceBaseAppMain.swift` embeds `SourceBaseRootView`.
- `SourceBaseiOS/Sources/SourceBaseiOS/App/SourceBaseApp.swift` owns root state wiring, StoreKit bootstrap, deep links, and navigation destination mapping.
- `SourceBaseiOS/Sources/SourceBaseiOS/Core/AppState.swift` owns bootstrap, initial-route selection, auth callbacks, and sign-out.
- Deep link scheme: `sourcebase://auth/callback`.

## Module Boundaries

- Internal dependency graph: `App` -> `SourceBaseiOS` -> `SourceBaseBackend`.
- `AuthBackend.shared` is the shared Supabase auth actor and client owner.
- `DriveAPI.invoke(action:payload:)` is the single Edge Function RPC envelope for Drive, generation, store, and IAP redemption actions.
- Repository layer: `DriveRepository`, `ProfileRepository`, `StoreRepository`.
- App stores/router: `AppState`, `SessionStore`, `AppRouter`, `SourceBaseWorkspaceStore`.
- Feature areas: `Auth`, `BaseForce`, `CentralAI`, `Drive`, `Profile`, `SourceLab`, `Study`.
- Design system: `SBColors`, `SBTypography`, `SBMotion`, `SBButton`, `SBCard`, `SBFileCard`, `SBStatusBadge`, `SBPremiumVisuals`, and related `SB*` primitives.

## Dependencies

- `SourceBaseBackend` depends on `supabase-swift` resolved at 2.46.0.
- `SourceBaseiOS` depends on `SourceBaseBackend`, `SwiftUI-Shimmer` 1.5.1, `Pow` 1.0.6, and `lottie-spm` 4.6.0.
- Transitive resolved packages include `swift-asn1`, `swift-clocks`, `swift-concurrency-extras`, `swift-crypto`, `swift-http-types`, and `xctest-dynamic-overlay`.

## Hotspots

Heuristic active-edit and complexity hotspots:

- `SourceBaseBackend/Sources/SourceBaseBackend/Drive/DriveRepository.swift`
- `SourceBaseiOS/Sources/SourceBaseiOS/Features/Study/GeneratedOutputStudyView.swift`
- `SourceBaseiOS/Sources/SourceBaseiOS/Core/SourceBaseWorkspaceStore.swift`
- `SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/ResultView.swift`
- `SourceBaseBackend/Sources/SourceBaseBackend/Drive/GeneratedContentModels.swift`
- Recently active feature clusters: `SourceLab`, `BaseForce` factory flows, `Study`, and `Drive/FileDetailView`.

## Tests

- Backend tests: `SourceBaseBackend/Tests/SourceBaseBackendTests/AuthTests.swift`, `DriveTests.swift`.
- iOS tests: `SourceBaseiOS/Tests/SourceBaseiOSTests/UploadAndOutputTests.swift`.

## Config And Compliance

- Runtime config: `SourceBaseConfig.fromEnvironment()` with env overrides for Supabase URL, anon key, public URL, and mobile redirect URL.
- The baked Supabase anon key is a public client token by design and is not reproduced in this index.
- App Store files: `App/SourceBase/PrivacyInfo.xcprivacy`, `App/SourceBase/SourceBase.entitlements`, and `App/SourceBase/Info.plist`.
- Custom URL scheme is declared in `Info.plist`.
- In-App Purchase capability is declared in the Xcode target attributes and StoreKit purchase flow is implemented in `SBStoreKitManager`.
