---
type: llm
focus: { source: file, path: events.md }
---

PASS if, while all three modules share one process, a relay inside that process (owned by its service lifecycle) reads pending outbox rows and delivers each to the Notifications and Loyalty consumers' use cases in-process, marking rows published on success and retrying with backoff; and an external broker is deferred until a consumer runs in another process (such as Notifications becoming a service), at which point only the relay's target changes.

FAIL if the design introduces Kafka, NATS, RabbitMQ, SQS, or another broker for the current single process, or if moving Notifications out would require changing the consumers' use cases.
