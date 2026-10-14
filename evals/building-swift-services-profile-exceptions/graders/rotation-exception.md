---
type: llm
focus: { source: file, path: boundaries.md }
---

PASS if the note allows the Users read inside the rotation transaction only as a narrow exception: it exists so a dependency outage does not destroy the caller's credential, and it holds only for one fast read in a short transaction with an explicit deadline well under the pool's wait time. It also says the exception does not cover provider writes (such as sending email) or Temporal calls, which run outside the transaction.

FAIL if it permits remote writes or workflow starts inside a transaction, presents the read as generally acceptable, or allows it without an explicit deadline.
