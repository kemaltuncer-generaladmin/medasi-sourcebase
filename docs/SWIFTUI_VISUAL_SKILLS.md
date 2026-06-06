# SourceBase SwiftUI Visual Skills

Scope: visual reference setup only. Do not use these notes to alter auth, payment, security, API, or backend code.

## Dependency Policy

SourceBase should stay mostly native SwiftUI:

- 80% native SourceBase custom design system: tokens, typography, spacing, cards, form controls, navigation, and states live in `SourceBaseiOS/Sources/SourceBaseiOS/DesignSystem`.
- 10% loading polish: use `SwiftUI-Shimmer` for skeleton placeholders in Drive file cards, generation queues, and document loading states.
- 10% motion polish: use `Pow` for small success/error feedback and card insert/remove transitions; use `Lottie` for premium onboarding, empty state, upload success, and generation progress assets.

Avoid adding broad UI kits as runtime dependencies. Study their structure, then adapt the idea into SourceBase components.

## Runtime SPM Dependencies

| Package | URL | Product | License | SourceBase Use |
| --- | --- | --- | --- | --- |
| SwiftUI-Shimmer | https://github.com/markiv/SwiftUI-Shimmer | `Shimmer` | MIT | Skeleton loading and shimmer placeholders. |
| Pow | https://github.com/EmergeTools/Pow | `Pow` | MIT | Micro-interactions, transitions, success/error feedback. |
| Lottie | https://github.com/airbnb/lottie-spm.git | `Lottie` | Apache-2.0 | Onboarding, empty states, upload success, generation progress. |

License check: MIT and Apache-2.0 are acceptable for commercial app usage with attribution/license notice preservation. Keep third-party notices current before App Store release.

## Reference-Only Sources

These are references only. Do not add them as dependencies and do not copy components verbatim.

| Source | URL | License | How To Use |
| --- | --- | --- | --- |
| SwiftUI Components | https://github.com/muhittincamdali/SwiftUI-Components | MIT | Component pattern reference for buttons, cards, forms, loading states, and empty states. |
| SwiftUI Design System Pro | https://github.com/muhittincamdali/SwiftUI-Design-System-Pro | MIT | Token/theme/component architecture reference. |
| DSKit SwiftUI | https://github.com/imodeveloper/dskit-swiftui | MIT | Screen structure and reusable UI composition reference. |
| Orbit SwiftUI | https://github.com/kiwicom/orbit-swiftui | MIT, archived | Enterprise design-system reference only; do not depend on archived package. |
| Orange ODS iOS | https://github.com/Orange-OpenSource/ods-ios | MIT, not maintained | Corporate component-standard reference only. Prefer OUDS for modern architecture. |
| Orange OUDS iOS | https://github.com/Orange-OpenSource/ouds-ios | MIT | Modern design-system architecture reference. |
| SwiftUI-Kit | https://github.com/jordansinger/SwiftUI-Kit | MIT | Native SwiftUI system interaction reference. |
| awesome-swiftui | https://github.com/onmyway133/awesome-swiftui | MIT | Discovery reference for SwiftUI resources and UI libraries. |
| awesome-swiftui-libraries | https://github.com/Toni77777/awesome-swiftui-libraries | MIT | Category-based discovery reference. |

## Implementation Guardrails

- Prefer `ViewModifier`, small `View` structs, and SourceBase design tokens over importing a large UI framework.
- Use `redacted(reason: .placeholder)` plus `.shimmering()` for skeletons.
- Keep Pow effects rare and semantic: success confirmation, destructive removal, queue item insertions, and state changes that benefit from feedback.
- Use Lottie only with curated local assets. Avoid generic AI-looking motion, heavy files, and assets that fight the native SwiftUI interface.
- New visual components belong under `SourceBaseiOS/Sources/SourceBaseiOS/DesignSystem` unless they are feature-specific.
- Any future visual dependency must pass: permissive license, active maintenance, clear product need, small API surface, and no overlap with native SwiftUI or existing SourceBase components.
