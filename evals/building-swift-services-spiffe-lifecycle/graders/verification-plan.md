---
type: llm
---

PASS only if the proposed tests cover a successful mTLS call; wrong expected server and missing/foreign client rejection; invalid update retaining the valid generation; expiry without another update; same-identity renewal; overlap then root removal on an active connection; and explicit termination of active work during emergency revocation. Assertions must describe externally observable acceptance/refusal/readiness or closure, not just method invocation. The answer distinguishes code sketches/proposed tests from executed checks.

FAIL if security tests only parse a URI, mock all TLS boundaries, rely solely on arbitrary sleeps, omit negative cases, or claim to have run builds/tests without tool evidence. Deterministic clocks/events or bounded waiting on observed conditions are acceptable.
