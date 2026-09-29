---
type: llm
---

PASS only if the gateway links products it uses, dials users/catalog with native mTLS, explicit roots and full DNS verification, and runs the standard reloader in its service group. It forwards the original bearer token on user services only; TLS private keys are distinct from JWT signing keys, and a gateway never receives the JWT private signing key. No certificate interceptor is required for an outgoing-only gateway. FAIL for custom security factory APIs, disabled hostname verification, missing direct imports/products, or minted replacement tokens.
