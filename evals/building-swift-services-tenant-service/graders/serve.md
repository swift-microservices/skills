---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
---

PASS if the composition root builds a PostgresDatabase (from swift-persistence-postgres) per role scope, one JWTAuthenticator<UserIdentity> from the public key, and one GRPCServer that applies BearerAuthenticationInterceptor followed by UserSettingsInterceptor to the user-facing service by descriptor and nothing to a public service.
FAIL if the interceptors are applied to a public service or per method, UserSettingsInterceptor is missing or precedes authentication, the database is built with a session object, or the file declares its own Database or PostgresDatabase type.
