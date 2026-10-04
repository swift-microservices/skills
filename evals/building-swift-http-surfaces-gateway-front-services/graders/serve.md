---
type: llm
focus: { source: file, path: acme-api/Sources/Acme/Serve/Serve.swift }
---

PASS if the serve command builds JWTAuthenticator<UserIdentity> from the public key, one GRPCClient per upstream service, BearerPropagationInterceptor<UserIdentity> applied only to the user-facing service descriptors, one generated stub per proto service, and runs them under a ServiceGroup; it reads no JWT signing key and opens no database. Calls to focused configuration factories are expected; trust configuration need not be inline in Serve.
FAIL if the propagating interceptor is applied to a public service or per call, a client is created per request, or a database or JWT signing key is used. A mounted TLS private key is required for mTLS and is not a JWT signing key.
