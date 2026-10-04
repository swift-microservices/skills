---
type: llm
focus: { source: file, path: acme-api/Sources/API/AcmeAPI.swift }
---

PASS if all of these hold:
- The authentication controller's routes (sign-in and refresh) are mounted in the first tier, before any group that adds `BearerAuthenticationMiddleware`.
- A second tier converts to `IdentityRequestContext` and adds `BearerAuthenticationMiddleware` over an authenticator of `UserIdentity`.
- A third tier adds `IsAuthenticatedMiddleware` on top of the second.
- `ErrorMiddleware` is added to the router before the tiers.

FAIL if the authentication routes are mounted on a group with the bearer middleware, or the identifying tier uses a different middleware.
