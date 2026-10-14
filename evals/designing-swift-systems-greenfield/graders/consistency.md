---
type: llm
focus: { source: file, path: design.md }
---

PASS if the design records, for each cross-module or cross-service write (at least order placement, payment, payout, and notifications), whether consistency is strong or eventual, and how duplicates and failures are handled (idempotency keys owned by the side effect's owner, consumers deduplicating by event id, retries bounded).

FAIL if consistency is left unstated for a cross-boundary write, exactly-once delivery is claimed, or retries are proposed without idempotency.
