---
name: ios-accessibility-minimal-auditor
description: iOS minimal accessibility audit, SwiftUI accessibility cleanup, VoiceOver labels, Dynamic Type, tap targets, contrast, dark mode, reduced motion, semantic grouping, and decorative accessibility noise removal. Use when Codex should improve accessibility in an iOS or SwiftUI app while keeping the interface simple, avoiding noisy hints, and making controls understandable out of context.
---

# iOS Accessibility Minimal Auditor

## Core Stance

Keep the app simple while preserving accessibility. Add only accessibility work that makes the app easier to use. Remove decorative accessibility noise.

Controls should be understandable out of context, but the app should not bury VoiceOver users in repeated hints or decorative labels.

## Audit Scope

Audit VoiceOver labels, traits, semantic grouping, Dynamic Type, tap targets, contrast, dark mode, reduced motion, focus order, form fields, images, icon-only buttons, destructive actions, loading states, empty states, error states, and custom controls.

## Minimal Fix Rules

- Add labels to icon-only buttons and ambiguous controls.
- Hide decorative images and icons from accessibility.
- Group repeated visual fragments only when it improves scanning.
- Avoid noisy hints on obvious controls.
- Preserve Dynamic Type with layouts that wrap instead of clipping.
- Keep tap targets comfortable and reachable.
- Respect Reduce Motion for nonessential animation.
- Make errors and required actions discoverable.
- Preserve contrast in light and dark mode.

## Output Format

- Accessibility issue
- User impact
- Minimal fix
- What not to overdo
- Manual VoiceOver/Dynamic Type checklist
