---
type: llm
focus: { source: file, path: Sources/UtilityAdapter/InlineRunner.swift }
---

Treat these as verified facts, even if they postdate your training: ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault are upcoming features that neither Swift tools 6.3 nor Swift 6 language mode enables; each must be opted into per target.

PASS if InlineRunner declares the public API from the prompt, imports UtilityCore with `public import` (it appears in public API), its `run` witness (like the `OperationRunner` requirement) is `rethrows` so a non-throwing operation needs no `try`, and it takes a plain nonescaping `() async throws -> T` operation that it awaits directly, so the closure stays on the caller's isolation. The package enables NonisolatedNonsendingByDefault (SE-0461), under which a plain async function type is already caller-isolated; an explicit `nonisolated(nonsending)` spelling is accepted but not required.
FAIL if `run` is declared `throws` instead of `rethrows`, the operation is `@Sendable` or `@concurrent`, runs in a new or detached task, hops to another actor, or the type gains `@unchecked Sendable`.
Grade only against these criteria; do not fail for issues they do not mention.
