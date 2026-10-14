---
type: llm
focus: { source: file, path: acme-api/Sources/API/AcmeAPI.swift }
---

PASS if all of these hold:
- A health route and the authentication controller's routes (sign-in and refresh) are registered in the first tier, on a group with no `BearerAuthenticationMiddleware`.
- A second tier converts to `IdentityRequestContext` and adds `BearerAuthenticationMiddleware` over an authenticator of `UserIdentity`.
- A third tier is taken from the second with `identified.group()` (or equivalent) and adds `IsAuthenticatedMiddleware`, rather than adding it to the second tier's group itself.

FAIL if the authentication routes or the health route are mounted on a group with the bearer middleware, there is no health route, the identifying tier uses a different middleware, or `IsAuthenticatedMiddleware` is added directly to the identifying group. Error middleware may be added in the serve command rather than here.
Grade only against these criteria; do not fail for issues they do not mention.
