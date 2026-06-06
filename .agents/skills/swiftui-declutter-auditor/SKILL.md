---
name: swiftui-declutter-auditor
description: SwiftUI declutter audit, iOS UI cleanup, redundant component removal, visual hierarchy simplification, and SwiftUI screen simplification. Use when Codex should inspect SwiftUI views/components/navigation/state/copy/spacing/buttons/icons/cards/lists/modals, find overdesigned or repeated UI, delete redundant SwiftUI code, and keep only interface elements that help the user complete the main task.
---

# SwiftUI Declutter Auditor

## Core Stance

Audit SwiftUI screens with a deletion-first mindset. Keep the interface native, obvious, and calm. Remove UI that exists only because the codebase has a component for it.

Prefer simple SwiftUI composition and native iOS patterns over decorative containers, repeated cards, excessive hierarchy, or too many custom controls.

## Audit Workflow

1. Inspect the target view, its reusable components, navigation wrappers, view models, state, copy, spacing, buttons, icons, cards, lists, sheets, and modals.
2. Identify the primary task on the screen.
3. Find every piece of UI that competes with that task.
4. Detect repeated components, unnecessary containers, duplicated labels, excessive badges, nested cards, confusing grouping, too many CTAs, and redundant states.
5. Prefer removing or flattening code before introducing abstractions.
6. When editing, keep changes local unless a shared component is clearly the source of repeated clutter.
7. Verify that the simplified UI still handles loading, empty, error, long text, small screens, Dynamic Type, and dark mode when relevant.

## Simplification Rules

- Delete helper text that restates the button or title.
- Collapse repeated card sections when a list or simple stack is clearer.
- Reduce multiple CTAs to one primary action and, at most, one secondary action.
- Replace decorative wrappers with semantic grouping only where needed.
- Keep icons only when they improve scanning or recognition.
- Avoid adding new design-system pieces unless the same simplification repeats across screens.

## Output Format

- Screen/component audited
- Clutter found
- Redundant SwiftUI code
- Suggested deletions
- Safer simplified implementation
- Manual verification checklist
