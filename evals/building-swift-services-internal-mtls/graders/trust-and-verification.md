---
type: llm
---

PASS if the final explanation:
- says internal admission rests on the explicit CA trust of a private listener, and that admitted peers can call internal operations without per-service application authorization;
- proposes handshake checks including at least a client with no certificate and one with an untrusted certificate;
- presents those checks as proposed, not as already performed.

FAIL if it presents unit tests as proof of TLS admission, requires a certificate identity to name the caller in application code, or claims renewal changes already-open connections.
