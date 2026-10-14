---
type: llm
focus: { source: file, path: Sources/AcmePersistence/UserSettingsMiddleware.swift }
---

Treat these as verified facts, even if they postdate your training: `@concurrent` is a valid Swift 6.2+ attribute (SE-0461), and under NonisolatedNonsendingByDefault Hummingbird 2's `RouterMiddleware` requirement is matched by `next: @concurrent (Request, Context) async throws -> Response`; `OperationContext.current` is nonoptional; copy it with `var operationContext = OperationContext.current` and use `guard let user = operationContext.user` to check for a bound user.

PASS if all of these hold:
- It is a public struct generic over a request context (`<Context: RequestContext>`) conforming to `RouterMiddleware`, with a public `init()`.
- With a user bound in `OperationContext.current.user`, it copies the current context, preserves its other values, and runs `next` inside `OperationContext.withContext` with `postgresSettings` set to `.user(user.identity)`.
- With no user bound, it calls `next` unchanged.

FAIL if it parses a header or token itself, makes an authorization decision, declares a `@TaskLocal`, or hard-codes a concrete context type.
Grade only against these criteria; do not fail for issues they do not mention.
