---
type: llm
focus: { source: file, path: acme-api/Sources/Acme/Serve/Serve.swift }
---

PASS only if the serve command builds JWTAuthenticator<UserIdentity> from the issuer public key, one GRPCClient per upstream, bearer propagation only on user-facing service descriptors, generated stubs, and a structured lifecycle. Each upstream client uses SPIFFE mTLS and its own exact configured users/catalog identity; the gateway's own identity is not used as the expected server.

FAIL if clients are created per request, public services receive propagated bearer tokens, upstream authentication accepts any server in the domain, or a database/private JWT signing key is opened. The gateway's TLS private key is required for mTLS and is allowed; do not conflate it with an issuer signing key.
