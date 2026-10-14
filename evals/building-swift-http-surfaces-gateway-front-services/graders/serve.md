---
type: llm
focus: { source: file, path: acme-api/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold:
- Serve builds a `JWTAuthenticator<UserIdentity>` from a public key (read through configuration, possibly via a helper defined in another file).
- It reads no JWT signing (private) key and opens no database or Postgres client. A mounted TLS private key for mTLS is not a JWT signing key.
- It hands the authenticator and the upstream stubs to the router builder (`AcmeAPI` and its `Dependencies`).

FAIL if a JWT signing key or a database is used, or the authenticator is not built from a public key.
Grade only against these criteria; do not fail for issues they do not mention.
