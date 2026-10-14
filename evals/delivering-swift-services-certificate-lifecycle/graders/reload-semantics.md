---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if all of these hold:
- Each process runs a primed `TimedCertificateReloader` per credential pair, owned by its service lifecycle, with billing's service and Temporal reloaders distinct.
- A renewed leaf is used by new handshakes; existing connections keep the old one, so connection age or drain is bounded.
- A failed reload keeps the last usable pair and retries.
- Trust-bundle (CA) rotation is an overlap rollout with transports rebuilt or processes restarted, because the leaf reloader does not reload trust roots.

FAIL if trust roots are said to reload through the leaf reloader, renewal is said to re-authenticate live connections immediately, or a process restart is the only normal way a renewed leaf takes effect.
