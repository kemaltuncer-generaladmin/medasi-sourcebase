---
name: swiftui-visual-master
description: Premium SwiftUI visual design skill for SourceBase. Use when redesigning SwiftUI screens, building design systems, adding motion/loading states, or translating Flutter UI patterns into native SwiftUI.
---

# SwiftUI Visual Master Skill

## Purpose

Use this skill to turn SourceBase SwiftUI screens into a premium medical education SaaS mobile experience.

The goal is not to copy any open source design system directly. The goal is to learn patterns from strong SwiftUI/component libraries and adapt them into a native SourceBase design system.

## Core Principles

- Build mostly native SwiftUI components.
- Avoid dependency bloat.
- Prefer custom SourceBase design tokens and reusable components.
- Keep UI premium, calm, clinical, modern, and human-made.
- Avoid AI-looking visuals, generic magic gradients, robot icons, excessive glass, excessive neon, and filler marketing text.
- Never break Qlinik.
- Do not touch backend/auth/payment/security unless explicitly asked.
- Do not print secrets, tokens, auth files, private keys, `.env`, or credential contents.

## Recommended Stack

### Real project dependencies only when needed

1. SwiftUI-Shimmer  
   URL: https://github.com/markiv/SwiftUI-Shimmer  
   Use for skeleton loading, Drive cards, upload state, generation waiting state.

2. Pow  
   URL: https://github.com/EmergeTools/Pow  
   Use for subtle micro-interactions, transitions, card feedback, success/error feedback.

3. Lottie  
   URL: https://github.com/airbnb/lottie-spm.git  
   Use for onboarding, empty states, upload success, generation progress. Keep assets non-generic and non-AI-looking.

### Reference-only sources

Do not add these as production dependencies unless explicitly requested.

- https://github.com/muhittincamdali/SwiftUI-Components
- https://github.com/muhittincamdali/SwiftUI-Design-System-Pro
- https://github.com/imodeveloper/dskit-swiftui
- https://github.com/kiwicom/orbit-swiftui
- https://github.com/Orange-OpenSource/ods-ios
- https://github.com/Orange-OpenSource/ouds-ios
- https://github.com/jordansinger/SwiftUI-Kit
- https://github.com/onmyway133/awesome-swiftui
- https://github.com/Toni77777/awesome-swiftui-libraries

## SourceBase Design System Targets

Create or improve these tokens:

- SourceBaseColors
- SourceBaseTypography
- SourceBaseSpacing
- SourceBaseRadius
- SourceBaseShadow
- SourceBaseMotion

Create or improve these components:

- SBPrimaryButton
- SBSecondaryButton
- SBCard
- SBGlassCard only when subtle
- SBStatusBadge
- SBSectionHeader
- SBMetricCard
- SBEmptyState
- SBLoadingState
- SBSourcePickerCard
- SBResultCard
- SBFeatureTile
- SBBottomActionBar
- SBSheetHeader

## Screen Priorities

When asked to polish the app, prioritize:

1. Ecosystem/Login entry
2. Drive
3. Source picker
4. BaseForce
5. SourceLab
6. Generated result screen
7. Profile/Settings
8. Loading/error/empty states

## Motion Rules

- Use subtle spring and ease animations.
- Use pressed states on tappable cards.
- Use shimmer for loading skeletons.
- Respect Reduce Motion where possible.
- Avoid confetti or flashy animation unless it is a rare success moment.

## iPhone QA Rules

Check:

- Safe area
- Bottom nav overlap
- Scroll behavior
- Text clipping
- Long Turkish text
- Keyboard overlap
- Sheet height
- CTA visibility
- Dynamic Type
- Light mode quality
- Dark mode not broken if enabled

## Build Rules

Before declaring done:

- Run package resolution if dependencies changed.
- Run build.
- Fix compile errors.
- Do not commit unless build passes.
- Summarize changed files and risks.
