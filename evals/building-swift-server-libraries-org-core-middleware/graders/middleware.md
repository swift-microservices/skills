---
type: llm
focus: { source: file, path: Sources/AcmePersistence/UserSettingsMiddleware.swift }
---

PASS if all of these hold:
- It is a public struct generic over a request context (`<Context: RequestContext>`) conforming to `RouterMiddleware`, with a public `init()`.
- With a user bound in `ServiceContext.current?.user`, it runs `next` inside `ServiceContext.withValue` with `postgresSettings` set to `.user(user.identity)`.
- With no user bound, it calls `next` unchanged.

FAIL if it parses a header or token itself, makes an authorization decision, declares a `@TaskLocal`, or hard-codes a concrete context type.
