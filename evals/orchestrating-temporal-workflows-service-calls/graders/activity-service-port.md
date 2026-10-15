---
type: regex
target: { source: file, path: acme-billing/Sources/BillingCore/PaymentReconciliation/Activities/PaymentReconciliationActivityService.swift }
match: not_contains
pattern: 'import\s+(?:Temporal|GRPC\w*|\w*Proto\w*)'
---
