---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- It builds `PostgresDatabase` values from swift-persistence-postgres over the role clients.
- It builds one `JWTAuthenticator<UserIdentity>` from the public key.
- One `GRPCServer` applies `BearerAuthenticationInterceptor` and then `UserSettingsInterceptor` to the documents service's descriptor, and nothing to an internal one.

FAIL if an interceptor is applied to an internal service or per method, `UserSettingsInterceptor` is missing or comes first, or the package declares its own database type.
