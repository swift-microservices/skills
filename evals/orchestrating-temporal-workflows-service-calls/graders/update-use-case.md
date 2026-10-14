---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsCore/Subscriptions/UseCases/UpdateSubscription/UpdateSubscriptionUseCase.swift }
---

PASS if all of these hold:
- `callAsFunction` takes `input:` alone: no `subject:`, process principal, or certificate identity.
- The use case validates what it is given itself: a required idempotency key is checked non-empty and length-bounded, and a refusal the input can cause (an unknown subscription, the key reused with different input, an illegal or lost transition) is a typed error of its own.
- The write runs inside `database.withTransaction`, through a repository command that carries the idempotency key (or a guarded transition), so a retry with the same key returns the original result or is a no-op. The atomic check lives in the repository's statement, which this file need not show; the file shows the key carried and the conflict or lost race mapped.

FAIL if it takes a user identity, accepts the update without any idempotency key or transition guard, checks for a prior update with a separate read before writing, or applies a repeated request twice.
