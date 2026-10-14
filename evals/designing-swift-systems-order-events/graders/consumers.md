---
type: llm
focus: { source: file, path: events.md }
---

PASS if delivery is at least once and each consumer is idempotent by event id: it records the event id in a table it owns with a unique constraint, in the same transaction as its own effect, so a redelivered event is a no-op; and a consumer's failure (the email provider being down) is retried with bounded attempts or parked without failing the checkout or blocking the other consumer.

FAIL if the design claims exactly-once delivery, deduplicates in memory or in the producer, or lets one consumer's failure roll back the order or block the other consumer.
