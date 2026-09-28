---
type: llm
focus: { source: file, path: acme-api/Sources/API/AcmeAPI.swift }
---

PASS if the router registers sign-in and refresh routes outside any authenticating middleware; an identifying tier under BearerAuthenticationMiddleware (from AuthenticationHummingbird, taking an authenticator) converting to IdentityRequestContext; a requiring tier under IsAuthenticatedMiddleware; and the ErrorMiddleware ahead of the tiers.
FAIL if sign-in or refresh sits behind the authenticating middleware, or the identifying tier uses a middleware other than AuthenticationHummingbird's BearerAuthenticationMiddleware over a UserIdentity authenticator.
