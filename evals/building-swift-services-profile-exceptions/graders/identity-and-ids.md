---
type: llm
focus: { source: file, path: boundaries.md }
---

Judge only how the caller's identity reaches the use cases and how identifiers are treated.

PASS if the note says the RPC handler requires the verified user (`requireUser()` or equivalent) and passes it to the use case as `subject:`, separately from the operation data; and the authenticator-assigned credential ID is validated and stored as given rather than replaced by a generated one. A note that never mentions retry keys passes; a deterministic workflow ID or a provider idempotency key derived from immutable input is not a misuse of an entity id.

FAIL if Core reads `OperationContext` (or a task-local) for the caller, the credential ID is regenerated or discarded, a service-owned row id is generated in Swift, or the credential ID or another entity id is presented as the retry or idempotency key for its own create.
Grade only against these criteria; do not fail for issues they do not mention.
