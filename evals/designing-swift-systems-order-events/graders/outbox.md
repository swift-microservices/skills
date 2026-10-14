---
type: llm
focus: { source: file, path: events.md }
---

PASS if placing an order records an order-placed fact in an outbox table in the same database transaction as the order itself (through a publisher port Orders' Core declares and calls inside its transaction), so the fact exists exactly when the order does, and PlaceOrderUseCase no longer calls Notifications or Loyalty.

FAIL if the event is published from memory after the commit, sent to a broker or to the consumers from inside the use case, or the consumers are still called before the checkout answers.
