---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift }
---

PASS if the Workflow waits for the verification signal with `context.condition` raced against `context.timeout` for the 24-hour window, catching Temporal's `CanceledError`, and on timeout runs an expiration Activity before assigning an expired state.
FAIL if it sleeps and polls, assigns the expired state before the expiration Activity, or never expires the registration.
