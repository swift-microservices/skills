---
type: llm
focus: { source: file, path: Sources/CatalogWebhooks/DeliveryLog.swift }
---

PASS if all of these hold:
- The shared set of delivered (or in-flight) item ids lives in an actor or behind a `Mutex`.
- Checking and claiming an id is one isolated operation (for example an actor method or one `withLock` closure returning whether the caller may send), so two racing callers cannot both claim the same id, and a failed delivery can release its claim.
- Any `@unchecked Sendable` carries a comment stating what makes it safe.

FAIL if the file is missing or a stub, the check and the insert are separate calls a racing caller can interleave, or state is guarded by a semaphore, `NSLock`, or a dispatch queue.
Grade only against these criteria; do not fail for issues they do not mention.
