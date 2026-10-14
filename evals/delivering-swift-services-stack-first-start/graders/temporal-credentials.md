---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if orders and the orders worker each mount a Temporal credential directory (for example at `/run/temporal-tls`) separate from their service-network directory, each with its own enrollment and renewer.
FAIL if a Temporal connection reuses the service-network pair, the two processes share one Temporal directory, or a Temporal directory has no renewer.
