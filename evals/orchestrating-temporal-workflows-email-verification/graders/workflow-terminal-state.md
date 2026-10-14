---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift }
---

PASS if the state the Workflow reports (through its result or a query) stays in progress until the Activity that establishes the terminal outcome has succeeded: expired only after the expiration Activity succeeds, and verified only once the verification is recorded (by an Activity that succeeded, or by the request whose committed change sent the signal).
FAIL if a terminal state is assigned before its Activity runs or while that Activity can still fail.
