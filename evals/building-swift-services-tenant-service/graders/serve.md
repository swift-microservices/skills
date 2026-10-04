---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- It builds `PostgresDatabase` values from swift-persistence-postgres over the role clients.
- It builds one `JWTAuthenticator<UserIdentity>` from the public key.
- One `GRPCServer` applies `BearerAuthenticationInterceptor` to the self and admin services' descriptors, and then `UserSettingsInterceptor` to the self service's descriptor only.

FAIL if an interceptor is applied to a public service or per method, `UserSettingsInterceptor` is missing or comes first, or the package declares its own database type.
