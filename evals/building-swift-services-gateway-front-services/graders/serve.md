---
type: llm
focus: { source: file, path: acme-api/Sources/Acme/Serve/Serve.swift }
---

PASS if the serve command builds JWTAuthenticator<UserIdentity> from the public key, one GRPCClient per upstream service, BearerPropagationInterceptor<UserIdentity> applied only to the user-facing service descriptors, one generated stub per proto service, and runs them under a ServiceGroup; it reads no private key and opens no database.
FAIL if the propagating interceptor is applied to a public service or per call, a client is created per request, or a database or private signing key is used.
