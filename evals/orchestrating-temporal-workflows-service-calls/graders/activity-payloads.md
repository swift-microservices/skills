---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingWorkflows/PaymentReconciliation/PaymentReconciliationActivities.swift }
---

PASS if the Activity inputs and outputs are nested `Codable` and `Sendable` types carrying stable business identifiers (the payment and subscription ids), the subscription update passes an idempotency key derived from that immutable input (identical on every attempt), and every Activity delegates to the Core Activity-service protocol.
FAIL if a payload carries a user JWT, bearer token, or other live credential, the key is a fresh `UUID()` or timestamp per attempt, or an Activity calls the gRPC client directly.
