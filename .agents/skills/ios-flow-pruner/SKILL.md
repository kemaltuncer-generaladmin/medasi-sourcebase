---
name: ios-flow-pruner
description: iOS flow pruning, navigation simplification, onboarding cleanup, auth/settings/create/edit/detail flow reduction, dead-end removal, duplicate path removal, and minimum-step UX design. Use when Codex should analyze iOS app flows, remove unnecessary branches and intermediate screens, fix confusing back navigation, merge duplicate steps, and reduce the user journey to the minimum number of useful steps.
---

# iOS Flow Pruner

## Core Stance

Prune the flow before improving it visually. A polished unnecessary step is still unnecessary.

Reduce onboarding, home, create/edit, detail, settings, auth, permission, paywall, and empty-state flows to the smallest path that still respects the user outcome and required edge cases.

## Workflow

1. Map the current flow from entry point to completed outcome.
2. Name the required user outcome in one sentence.
3. Identify every branch, modal, confirmation, permission prompt, intermediate screen, and back-navigation path.
4. Remove dead ends, loops, duplicate paths, repeated confirmations, and screens that only restate the previous screen.
5. Merge steps when the user can make the decision safely in one place.
6. Keep only necessary edge-case handling: validation, permissions, payment, destructive actions, auth, offline, retry, and data loss prevention.
7. If implementation is requested, update navigation and state together so the app cannot route into deleted branches.

## Pruning Rules

- Prefer one clear entry path over many equivalent routes.
- Prefer inline validation over late alerts.
- Prefer a single final confirmation only for destructive or irreversible actions.
- Prefer automatic sensible defaults over setup choices.
- Prefer direct return to the useful destination after completion.
- Preserve back behavior that matches iOS expectations.

## Output Format

- Current flow
- Required user outcome
- Steps that can be deleted
- Steps that can be merged
- Final simplified flow
- Edge cases that still need handling
