---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift }
---

PASS if all of these hold:
- Issuing the verification token and sending the email are separate Activities.
- The Workflow waits on the verification signal with `context.condition` raced against `context.timeout` for the verification window, catching Temporal's `CanceledError`.
- On timeout it runs an expiration Activity before assigning an expired state.
- Its `Input` is nested, `Codable`, and `Sendable`.

FAIL if the Workflow performs database or network work directly, or reads `Date()` or `Date.now` rather than `context.now`, calls `UUID()`, or uses a random source outside the Workflow context.
