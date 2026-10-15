---
runs: 1
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal, webhooks]
---

Our Swift service "billing" (package acme-billing, targets BillingCore, BillingPostgres, BillingGRPC, BillingStripe, Billing, on grpc-swift and PostgresNIO) receives Stripe webhooks through `BillingService.HandleStripeWebhook`, an RPC anyone may call, carrying the raw payload and the `Stripe-Signature` header. When a `checkout.session.completed` event arrives for a one-time purchase, the buyer must get a license. The entitlements service owns licenses and exposes `EntitlementInternalService.GrantEntitlement`, which accepts an idempotency key. Stripe retries a webhook until it gets a 2xx, and may deliver an event more than once or out of order; an event can also arrive before the payment has settled.

Make fulfillment durable with the Swift Temporal SDK, under ./acme-billing. Write only these files: the webhook use case in Sources/BillingCore/Fulfillment/UseCases/HandleStripeWebhook/HandleStripeWebhookUseCase.swift; Sources/BillingWorkflows/Fulfillment/FulfillmentWorkflow.swift, FulfillmentActivities.swift, and TemporalFulfillmentWorkflowClient.swift beside it. Billing's worker already runs `SubscriptionWorkflow` with its `SubscriptionActivities` container (Sources/BillingWorkflows/Subscriptions/), whose Activities include `fetchCheckoutSession` and `grantEntitlement`; it must keep running them beside fulfillment. Put a test that the worker's combined registration is sound in Tests/BillingWorkflowsTests/BillingWorkerRegistrationTests.swift. Don't build or resolve packages.
