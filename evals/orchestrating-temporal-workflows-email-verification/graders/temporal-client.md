---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/TemporalEmailVerificationWorkflowClient.swift }
---

PASS if the Temporal client adapter conforms to the Core workflow-client port, derives the workflow ID from the registration id, and starts with an ID-reuse policy that rejects duplicates and a conflict policy that uses the existing run.
FAIL if the workflow ID is random or the start can create a second run for the same registration.
