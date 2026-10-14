---
type: llm
focus: { source: file, path: swift-persistence-memory/Sources/PersistenceMemory/MemoryDatabase.swift }
---

The driver may define its scope type in another file, but the transaction logic itself must be in this file.

PASS if all of these hold:
- `withTransaction` takes a copy of the stored state, hands the operation a scope over that copy, and replaces the stored state with the copy only after the operation returns; when the operation throws, the stored state is left unchanged and the same error is rethrown.
- The stored state is protected by a `Mutex` or an actor (an `@unchecked Sendable` type is acceptable only with a comment stating what makes it safe).
- The operation runs on the caller's isolation: its parameter is plain and nonescaping, neither `@Sendable` nor `@concurrent`, and the method is not isolated to an actor (a `nonisolated` method on an actor is fine).

FAIL if `withTransaction` is a stub (`fatalError`, an empty or placeholder body, or a `TODO`), runs the operation against the live state with no copy-and-commit step, wraps or swallows the thrown error, guards state with a semaphore or an `NSLock`-style lock inside async code, or leaves mutable state unprotected.
Grade only against these criteria; do not fail for issues they do not mention.
