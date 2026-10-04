---
type: llm
focus: { source: file, path: swift-persistence-memory/Sources/PersistenceMemory/MemoryDatabase.swift }
---

The driver may use helper types defined in other files; judge only what this file shows.

PASS unless one of these defects is visible:
- `withTransaction`'s `operation` parameter is marked `@Sendable` or `@concurrent`.
- The database is an `actor`, or wraps the operation in a call that runs it on another actor.
- A thrown error is wrapped in another error type or swallowed.
- Mutable shared state is stored without protection (a plain `var` in a class with no `Mutex` or lock), or `@unchecked Sendable` appears with no comment explaining why it is safe.
- A public declaration has no `///` comment.
- The file bootstraps logging or reads environment variables.
