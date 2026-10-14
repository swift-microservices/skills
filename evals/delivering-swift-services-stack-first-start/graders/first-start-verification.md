---
type: llm
focus: { source: file, path: stack/FIRST-START.md }
---

PASS if verification after `up` checks which database roles connected (`pg_stat_activity` showing the service, internal, and worker roles, never the owner), runs a real mTLS handshake against an internal listener (accounts or orders) that admits a stack certificate and refuses a missing one, and sends a request through the public hostname.
FAIL if verification is only that containers are running or healthy.
