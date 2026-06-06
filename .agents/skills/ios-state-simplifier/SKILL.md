---
name: ios-state-simplifier
description: iOS state simplification, SwiftUI loading/empty/error/success/permission/offline state cleanup, ViewModel state reduction, async/await state audit, duplicate flag removal, impossible state removal, and user recovery UX. Use when Codex should inspect SwiftUI views, view models, services, models, and async code to delete redundant states, fix infinite spinners or unclear errors, and create one clear state model per screen.
---

# iOS State Simplifier

## Core Stance

Every state must help the user continue, recover, or understand what is happening. Delete states that exist only to mirror implementation details.

Prefer one clear state model per screen over scattered booleans and unreachable branches.

## Workflow

1. Inspect the SwiftUI view, view model, model, service, and async/await code involved in the target screen.
2. List the visible states: loading, empty, loaded, error, success, permission, offline, validation, retry, and disabled.
3. Find duplicate flags, impossible combinations, unreachable enum cases, infinite spinners, unclear errors, unused success banners, and unnecessary alerts.
4. Collapse state into the smallest model that can represent the real user-visible conditions.
5. Make each state show one clear next action or recovery path.
6. Delete unused branches and update tests or previews when relevant.

## Simplification Rules

- Prefer an enum when states are mutually exclusive.
- Prefer derived values over stored duplicate flags.
- Avoid showing loading when cached content can stay visible.
- Avoid separate success states when navigation or visible content already confirms success.
- Prefer inline retry for recoverable failures.
- Keep destructive, payment, auth, permission, and data-loss states explicit.

## Output Format

- State model reviewed
- Redundant states
- Missing states
- States to delete
- Simpler state model
- Test cases
