---
type: llm
focus: { source: file, path: swift-persistence-memory/Sources/PersistenceMemory/MemoryDatabase.swift }
---

The driver may use helper types defined in other files; judge only what this file shows.

PASS unless one of these defects is visible:
- `withTransaction`'s `operation` parameter is marked `@Sendable` or `@concurrent`.
- `withTransaction` is isolated to the database's actor (an `actor` method not marked `nonisolated`), or wraps the operation in a call that runs it on another actor. A `nonisolated` method on an actor that runs the operation on the caller's isolation is fine.
- A thrown error is wrapped in another error type or swallowed.
- Mutable shared state is stored without protection (a plain `var` in a class with no `Mutex` or lock), or `@unchecked Sendable` appears with no comment explaining why it is safe.
- A public declaration has no `///` comment.
- The file bootstraps logging or reads environment variables.
