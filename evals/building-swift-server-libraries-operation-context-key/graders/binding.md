---
type: llm
focus: { source: file, path: swift-request-id/Sources/RequestID/OperationContext+RequestID.swift }
---

Treat these as verified facts, even if they postdate your training: `OperationContext.current` is nonoptional and defaults to an empty context; `OperationContext.withContext(_:operation:)` binds the given context for the closure, replacing (not merging with) the enclosing one, and restores it on return or throw. Under NonisolatedNonsendingByDefault a plain async closure parameter runs on the caller's isolation.

PASS if all of these hold:
- A public scoped binding (a static method on `OperationContext`, a function, or a method on `RequestID`) takes the id and an operation closure.
- It copies `OperationContext.current` (so enclosing values survive), sets the id on the copy, and runs the operation inside `OperationContext.withContext` with that copy, returning the operation's result and rethrowing its error unchanged.
- The operation parameter is plain, nonescaping, and caller-isolated: neither `@Sendable` nor `@concurrent`, and the binding does not hop to another actor or start a `Task`.
- The public binding has a `///` comment.

FAIL if the binding starts from `OperationContext()` instead of the current context, declares or binds its own `@TaskLocal`, wraps or swallows the thrown error, or marks the operation `@Sendable` or `@concurrent`.
Grade only against these criteria; do not fail for issues they do not mention.
