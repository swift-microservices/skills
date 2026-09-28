---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift }
---

PASS if the Workflow waits on a condition (the verification signal) raced against a timer of the registration's expiration taken from its input, runs an expiration Activity before assigning an expired state, calls email delivery and verification-token issuance as separate Activities, and uses only the Workflow context for time and identifiers; its input, state, and result are Codable and Sendable.
FAIL if the Workflow performs database or network work directly, or calls Date(), UUID(), or a random source outside the Workflow context.
