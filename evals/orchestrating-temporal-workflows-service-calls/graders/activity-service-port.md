---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingCore/PaymentReconciliation/Activities/PaymentReconciliationActivityService.swift }
---

PASS if the file declares a `Sendable` Activity-service protocol in Core terms (ids, an idempotency key, Core types or typed errors) and its implementation reaches accounts only through a capability-named Core port, not through generated gRPC types.
FAIL if the file imports Temporal, GRPCCore, or generated protobuf types, or takes a token or user session.
