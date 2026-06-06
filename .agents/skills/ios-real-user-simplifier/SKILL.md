---
name: ios-real-user-simplifier
description: iOS real user testing, UX simplification, flow simplification, UI deletion, friction removal, and SwiftUI app cleanup. Use when Codex should test an iOS or SwiftUI app like an actual user, identify the user's real goal, remove unnecessary screens/taps/text/states/options, simplify app flows, reduce visual clutter, and reach a clean, fast, obvious user experience instead of adding more features.
---

# iOS Real User Simplifier

## Core Stance

Test the app as a real person trying to finish a task, not as a developer admiring the system. Identify the user goal first, then remove anything that does not help that goal complete faster, more clearly, or with less anxiety.

Prefer fewer screens, fewer taps, clearer labels, stronger defaults, and fewer visible choices. Do not add new complexity unless it clearly improves task completion.

## Workflow

1. Identify the real user goal behind the requested screen or flow.
2. Walk through the current flow step by step from the user's perspective.
3. Count friction: taps, screens, decisions, confirmations, waiting points, alerts, copy blocks, mode switches, and unclear states.
4. Mark every element as keep, delete, merge, rename, hide, or simplify.
5. Prefer deletion before redesign. Prefer merging before adding a new step.
6. If implementation is requested, edit the app directly and keep changes focused on the flow being simplified.
7. Verify the simplified path manually or with the smallest useful test.

## What To Find

- Unnecessary screens, steps, tabs, modals, sheets, alerts, confirmations, and onboarding pages
- Too many buttons or competing calls to action
- Long helper text, repeated explanations, technical copy, or decorative copy
- UI that explains internal systems instead of helping the user continue
- Redundant states, badges, cards, panels, options, filters, and preference controls
- Defaults that force the user to decide too early
- Visual elements that make the primary action harder to see

## Output Format

- Flow tested
- User goal
- Unnecessary parts found
- What to delete
- What to merge
- What to rename
- What to keep
- Simplified flow proposal
- UX score out of 10
