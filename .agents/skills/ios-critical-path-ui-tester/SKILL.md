---
name: ios-critical-path-ui-tester
description: iOS critical path UI testing, focused XCUITest, focused XCTest, real user path coverage, accessibilityIdentifier selection, brittle test avoidance, and minimal test creation for Swift/SwiftUI apps. Use when Codex should add or propose only the UI tests that protect the most important user flows, covering happy path, empty state, error state, validation, and retry only where those paths matter.
---

# iOS Critical Path UI Tester

## Core Stance

Protect the app's most important user paths without creating a brittle test pile. Add tests only where failure would hurt real users or repeatedly regress.

Do not generate excessive tests. Prefer a few stable XCUITest/XCTest cases over broad fragile coverage.

## Workflow

1. Identify the critical flows users rely on most.
2. Choose the smallest set of paths worth automated protection.
3. Prefer tests around task completion, validation, empty state, error state, retry, and recovery only for critical flows.
4. Add `accessibilityIdentifier` only where necessary for stable selection.
5. Avoid assertions against decorative text, implementation details, animation timing, or unstable ordering.
6. Keep tests readable and close to user behavior.
7. Run the focused test target when possible and report any remaining manual checks.

## Test Selection Rules

- Test the happy path when it protects revenue, auth, creation, upload, generation, search, save, or user-visible completion.
- Test empty/error/retry only if the user can realistically hit those states.
- Test validation when it prevents broken submissions or data loss.
- Skip tests for purely decorative UI, incidental layout, and one-off copy unless it is the actual contract.
- Prefer manual verification for visual polish, motion feel, and exploratory UX.

## Output Format

- Critical paths selected
- Why these paths matter
- Tests added or proposed
- Files changed
- How to run
- What remains manual
