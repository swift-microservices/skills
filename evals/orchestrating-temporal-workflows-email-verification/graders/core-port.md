---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsCore/Registrations/EmailVerification/EmailVerificationWorkflowClient.swift }
---

PASS if the Core port is a protocol that does not import Temporal, and the workflow state and result values it exposes are the only Temporal payloads declared in AccountsCore, declared Codable and Sendable.
FAIL if the file imports Temporal or declares Activity inputs or outputs.
