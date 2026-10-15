---
type: regex
target: { source: file, path: acme-billing/Sources/BillingWorkflows/PaymentReconciliation/PaymentReconciliationActivities.swift }
match: not_contains
pattern: 'UUID\(\)|[Bb]earer|accessToken'
---
