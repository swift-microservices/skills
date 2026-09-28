---
type: llm
focus: { source: file, path: acme-api/Sources/API/AcmeAPI.swift }
---

PASS if the router registers sign-in and refresh routes outside any authenticating middleware; an identifying tier under BearerAuthenticationMiddleware (from AuthenticationHummingbird, taking an authenticator) converting to IdentityRequestContext; a requiring tier under IsAuthenticatedMiddleware; and the ErrorMiddleware ahead of the tiers.
FAIL if sign-in or refresh sits behind the authenticating middleware or is excluded by a path check inside it, the middleware is TokenAuthenticationMiddleware, or the identity type is UserPayload.
