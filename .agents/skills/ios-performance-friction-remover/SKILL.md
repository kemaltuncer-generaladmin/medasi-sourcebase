---
name: ios-performance-friction-remover
description: iOS performance friction removal, SwiftUI performance audit, launch speed cleanup, scroll jank reduction, image loading optimization, async work cleanup, repeated network call removal, unnecessary re-render reduction, and user-visible latency fixes. Use when Codex should inspect code for performance issues users can feel and apply the simplest fix instead of premature complex optimization.
---

# iOS Performance Friction Remover

## Core Stance

Optimize only the friction users can feel: slow launch, blocked first screen, delayed tap feedback, repeated loading, stuttery scrolling, expensive SwiftUI body work, unnecessary network calls, and sluggish images.

Avoid premature complex optimization. Remove unnecessary work first.

## Workflow

1. Identify the user-visible friction and where the user feels it.
2. Inspect launch, scrolling, image loading, async work, repeated network calls, large lists, expensive SwiftUI bodies, and state changes.
3. Trace the simplest cause in code before adding infrastructure.
4. Remove duplicate work, defer noncritical work, cache obvious repeated data, avoid main-thread blocking, and reduce unnecessary re-renders.
5. Keep tap feedback immediate even when the operation continues asynchronously.
6. Verify with manual interaction, logs, Instruments, XCTest metrics, or lightweight timing checks when available.

## Fix Priority

- Faster first useful screen
- Smoother scrolling and list rendering
- Quicker tap feedback
- Fewer blocking operations
- Fewer repeated network calls
- Less work in SwiftUI body and computed view builders
- Better image sizing, caching, and placeholder behavior

## Output Format

- User-visible friction
- Cause in code
- Simplest fix
- Files to change
- Measurement or manual check
