---
type: llm
focus: { source: file, path: Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold:
- A health route is registered on a group with no authenticating middleware, and the item reads are registered where anonymous callers are admitted (that group or the identifying tier).
- An identifying tier converts to `IdentityRequestContext`, adds `BearerAuthenticationMiddleware` over the `UserIdentity` authenticator, and then `UserSettingsMiddleware`.
- A requiring tier is taken from the identifying one with `identified.group()` (or equivalent) and adds `IsAuthenticatedMiddleware`; the favourites routes are mounted there.

FAIL if `UserSettingsMiddleware` is missing or precedes the bearer middleware, `IsAuthenticatedMiddleware` is added to the identifying group itself, or there is no health route outside the authenticating tiers.
Grade only against these criteria; do not fail for issues they do not mention.
