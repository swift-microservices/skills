---
type: llm
---

PASS if the explanation identifies explicit CA trust and private listener exposure as the internal admission boundary, states that admitted peers can call internal APIs without per-service application authorization, and proposes real handshake checks for a trusted certificate, no certificate, an untrusted certificate, a wrong server hostname, and a newly renewed leaf on a fresh connection. It distinguishes proposed tests from executed evidence and notes that leaf reload does not update trust roots or re-authenticate an already-open connection.
FAIL if ordinary unit tests are presented as proof of TLS admission, a certificate URI is required to name the caller in application code, renewal is claimed to change existing connections immediately, or internal handlers are routed through the public HTTP gateway.
