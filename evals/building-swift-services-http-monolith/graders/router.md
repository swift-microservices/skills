---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold:
- The router has an identifying tier that converts to `IdentityRequestContext` and adds `BearerAuthenticationMiddleware` (over a `JWTAuthenticator<UserIdentity>`) followed by `UserSettingsMiddleware`.
- A requiring tier adds `IsAuthenticatedMiddleware` on top of it, and the notebooks routes are mounted there.
- Any session-issuing routes (sign-up, sign-in, refresh) and the health route are mounted outside the bearer middleware.

FAIL if `UserSettingsMiddleware` is missing or added before the bearer middleware, a session-issuing route sits behind the bearer middleware, or Serve.swift declares its own `Database` type instead of using `PostgresDatabase`.
