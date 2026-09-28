---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if the composition root mounts the modules' controllers on one Hummingbird router; sign-up and sign-in are registered outside any authenticating middleware; the identifying tier applies BearerAuthenticationMiddleware (from AuthenticationHummingbird, over a JWTAuthenticator<UserIdentity> built from the public key) followed by UserSettingsMiddleware, so the tenant setting is bound per request; and the package uses PostgresDatabase from swift-persistence-postgres rather than declaring its own.
FAIL if the bearer middleware covers sign-up or sign-in, if UserSettingsMiddleware is missing or runs before authentication, or if the tenant setting is bound per module or per connection.
