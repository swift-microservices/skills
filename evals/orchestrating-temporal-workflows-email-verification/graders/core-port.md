---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsCore/Registrations/EmailVerification/EmailVerificationWorkflowClient.swift }
---

PASS if the file declares the workflow-client port as a `Sendable` protocol (start, signal, and state or result operations keyed by the registration id) and does not import Temporal. State and result types may be declared in other files.

FAIL if the file imports Temporal, declares Activity inputs or outputs, or exposes Temporal SDK types in the protocol.
