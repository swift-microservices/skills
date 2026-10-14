---
type: llm
focus: { source: file, path: verification.md }
---

PASS if the plan proves a rotation by observing the served leaf's serial number or fingerprint change on a fresh connection without restarting the process, checks that a failed reload keeps the last usable pair and recovers, and covers CA trust rotation with an overlap.
FAIL if file timestamps or the renewed files on disk are the only evidence the live process presents the new leaf.
