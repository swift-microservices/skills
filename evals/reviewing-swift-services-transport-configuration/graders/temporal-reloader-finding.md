---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a finding, citing Serve.swift, that the Temporal client is given the service `reloader`, so it presents the service certificate pair instead of its own `temporal.tls` pair, and needs its own primed reloader in the `ServiceGroup`.
FAIL if the finding is missing or has no file reference, or the report says the Temporal client already uses its own pair.
