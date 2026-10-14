---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingCore/Fulfillment/UseCases/HandleStripeWebhook/HandleStripeWebhookUseCase.swift }
---

PASS if the use case verifies the Stripe signature through a Core port (no Stripe SDK or Temporal import in the file), maps a failed verification to a typed error, and for a completed checkout starts the fulfillment workflow through a Core workflow-client port with the session id and event id, without opening a database transaction around the start and without granting anything itself.

FAIL if the file imports Temporal or the Stripe SDK, skips signature verification, grants the license or calls entitlements directly, or calls Temporal inside a transaction.
