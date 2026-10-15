---
max_turns: 120
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal, webhooks]
---

Our Swift service "billing" (package acme-billing, targets BillingCore, BillingPostgres, BillingGRPC, BillingStripe, Billing, on grpc-swift and PostgresNIO) receives Stripe webhooks through `BillingService.HandleStripeWebhook`, an RPC anyone may call, carrying the raw payload and the `Stripe-Signature` header. When a `checkout.session.completed` event arrives for a one-time purchase, the buyer must get a license. The entitlements service owns licenses and exposes `EntitlementInternalService.GrantEntitlement`, which accepts an idempotency key. Stripe retries a webhook until it gets a 2xx, and may deliver an event more than once or out of order; an event can also arrive before the payment has settled.

Make fulfillment durable with the Swift Temporal SDK, including whatever process runs it. Write the new files under ./acme-billing and finish with a short summary of what runs where. Use these paths for the main pieces: the webhook use case in Sources/BillingCore/Fulfillment/UseCases/HandleStripeWebhook/HandleStripeWebhookUseCase.swift; Sources/BillingWorkflows/Fulfillment/FulfillmentWorkflow.swift, FulfillmentActivities.swift, and TemporalFulfillmentWorkflowClient.swift beside it; and the worker's composition root in Sources/Billing/Worker/Run.swift. Billing's worker already runs `SubscriptionWorkflow` with its `SubscriptionActivities` container (Sources/BillingWorkflows/Subscriptions/), whose Activities include `fetchCheckoutSession` and `grantEntitlement`; it must keep running them beside fulfillment. Put a test that the worker's combined registration is sound in Tests/BillingWorkflowsTests/BillingWorkerRegistrationTests.swift. Billing, entitlements, and the self-hosted Temporal frontend all require client certificates; one Temporal server serves staging and production, so the project gives Temporal its own credential pair.
