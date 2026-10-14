---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if all of these hold:
- Each workload enrolls its first pair before its application starts, using a short-lived, single-use credential scoped to that workload (for example a token from that workload's own provisioner).
- Each issued leaf carries the DNS names clients and the edge proxy actually dial and both server and client TLS purposes.
- Secrets in commands and fragments are placeholders.

FAIL if any workload's credential can enroll another workload's identity, renewers can enroll arbitrary peers, private keys are baked into images, or the design requires application URI identities to authorize RPCs.
