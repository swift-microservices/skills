---
type: regex
target: { source: file, path: acme-billing/Sources/BillingCore/Fulfillment/UseCases/HandleStripeWebhook/HandleStripeWebhookUseCase.swift }
match: not_contains
pattern: 'import\s+(?:Temporal|Stripe)|withTransaction'
---
