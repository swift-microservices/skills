---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift }
---

PASS if the Workflow reaches every side effect (issuing the token, sending the email, expiring the registration) through Activities, reads time only as `context.now`, and declares its `Input` nested under the Workflow as `Codable` and `Sendable`.
FAIL if the Workflow does database or network work directly, or calls `Date()`, `Date.now`, `UUID()`, or a random source.
