---
name: test-writer-fixer
description: Test automation, focused test writing, existing test execution, failure analysis, and test repair after code changes. Use when Codex modifies code, refactors behavior, fixes bugs, adds features, or finds missing coverage in critical Swift, SwiftUI, XCTest, XCUITest, JavaScript, Python, or backend modules.
---

# Test Writer Fixer

## Core Stance

Keep the test suite useful, trustworthy, and aligned with real behavior. After code changes, run the smallest relevant test scope first, expand only when risk warrants it, and fix failures without weakening the test's protective value.

Do not add a large brittle test pile. Prefer focused tests that catch real regressions in critical flows.

## When To Use

- Code was changed, refactored, or moved.
- A bug fix needs verification.
- A new feature or user-visible behavior was added.
- A critical module has little or no coverage.
- Existing tests fail after a legitimate behavior change.
- A flaky or brittle test blocks meaningful validation.

## Workflow

1. Identify the changed files, affected modules, and user-visible behavior.
2. Find nearby tests and project test commands before inventing a new pattern.
3. Start with focused tests for the touched module or flow.
4. If failures appear, classify them as code bug, stale expectation, brittle test, environment issue, or missing setup.
5. Fix tests only when the product behavior is correct and the old expectation is wrong or brittle.
6. Fix code only when tests reveal a real bug.
7. Expand to broader tests when the change touches shared behavior, contracts, auth, generation, upload, persistence, or navigation.
8. Report what ran, what failed, what changed, and what remains unverified.

## Test Writing Rules

- Test behavior, not implementation details.
- Use descriptive test names that document the behavior.
- Cover happy path, edge cases, validation, error, retry, and empty states only where they matter to real users.
- Prefer stable selectors such as `accessibilityIdentifier` for UI tests.
- Avoid assertions on decorative copy, animation timing, incidental ordering, or unstable formatting.
- Mock external dependencies only at clear boundaries.
- Preserve existing local test style, helpers, factories, and naming.
- Never weaken assertions merely to make the suite green.

## Failure Repair Rules

- If a test fails because the product behavior is wrong, fix the code.
- If a test fails because expected behavior intentionally changed, update the expectation and keep the same behavioral protection.
- If a test is brittle, make it more resilient without reducing coverage.
- If the environment blocks execution, diagnose enough to name the blocker and run any lower-cost validation available.
- If test intent is unclear, inspect neighboring tests, production code, comments, and recent changes before editing.

## SourceBase Defaults

- For Swift package work, prefer `swift test` or the narrowest relevant XCTest command when available.
- For iOS app work, prefer focused `xcodebuild test` or build verification for the affected scheme and simulator.
- For critical SourceBase flows, prioritize auth, Drive upload, generation job lifecycle, generated output recovery, result display, and user-visible error recovery.
- Do not touch Qlinik, secrets, backend contracts, or unrelated flows while repairing tests.

## Output Format

- Changed behavior under test
- Tests added or repaired
- Commands run and results
- Any failures that indicate product bugs
- Remaining risk or manual checks
