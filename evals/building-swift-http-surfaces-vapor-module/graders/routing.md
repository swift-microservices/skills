---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold:
- The notes routes sit in a group that adds swift-authentication-vapor's `BearerAuthenticationMiddleware` and then `UserSettingsMiddleware`.
- A further group adds `UserIdentity.guardMiddleware()` before the notes routes.
- Any session-issuing route sits outside the bearer middleware.

FAIL if `UserSettingsMiddleware` is missing or comes before the bearer middleware, the notes routes are reachable without `guardMiddleware()`, or Vapor's own bearer authenticator replaces the package middleware.
