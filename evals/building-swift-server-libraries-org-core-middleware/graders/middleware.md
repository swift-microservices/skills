---
type: llm
focus: { source: file, path: Sources/AcmePersistence/UserSettingsMiddleware.swift }
---

Treat these as verified facts, even if they postdate your training: `@concurrent` is a valid Swift 6.2+ attribute (SE-0461), and under NonisolatedNonsendingByDefault Hummingbird 2's `RouterMiddleware` requirement is matched by `next: @concurrent (Request, Context) async throws -> Response`; `guard var serviceContext = ServiceContext.current, let user = serviceContext.user` is one way to read `ServiceContext.current?.user`.

PASS if all of these hold:
- It is a public struct generic over a request context (`<Context: RequestContext>`) conforming to `RouterMiddleware`, with a public `init()`.
- With a user bound in `ServiceContext.current?.user`, it runs `next` inside `ServiceContext.withValue` with `postgresSettings` set to `.user(user.identity)`.
- With no user bound, it calls `next` unchanged.

FAIL if it parses a header or token itself, makes an authorization decision, declares a `@TaskLocal`, or hard-codes a concrete context type.
