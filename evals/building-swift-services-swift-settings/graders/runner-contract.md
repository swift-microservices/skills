---
type: llm
focus: { source: file, path: Sources/UtilityAdapter/InlineRunner.swift }
---

PASS if InlineRunner keeps its public API, imports UtilityCore with `public import` (it appears in public API), and its `run` witness takes a plain nonescaping `() async throws -> T` operation that it awaits directly, so the closure stays on the caller's isolation. The package enables NonisolatedNonsendingByDefault (SE-0461), under which a plain async function type is already caller-isolated; an explicit `nonisolated(nonsending)` spelling is accepted but not required.
FAIL if the operation is `@Sendable` or `@concurrent`, runs in a new or detached task, hops to another actor, or the type gains `@unchecked Sendable`.
