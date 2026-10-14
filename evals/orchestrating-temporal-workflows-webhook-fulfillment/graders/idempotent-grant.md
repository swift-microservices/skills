---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingWorkflows/Fulfillment/FulfillmentActivities.swift }
---

PASS if all of these hold:
- Re-fetching the session and granting the license are separate Activities that delegate to a Core protocol (the Activity-service port), not to the Stripe SDK or a generated gRPC client.
- The grant passes an idempotency key derived from immutable input, such as the checkout session id, identical on every attempt.
- Activity inputs and outputs are nested under the container and are `Codable` and `Sendable`; none is a BillingCore entity.
- Permanent failures, such as an invalid session or a price that maps to no license, are thrown as non-retryable `ApplicationError`s.

FAIL if an Activity mints a fresh UUID or timestamp for the idempotency key, returns a Core entity or the Stripe SDK's session type, or retries a permanent failure indefinitely.
