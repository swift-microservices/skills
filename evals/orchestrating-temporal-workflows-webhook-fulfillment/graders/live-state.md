---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingWorkflows/Fulfillment/FulfillmentWorkflow.swift }
---

PASS if all of these hold:
- The Workflow's nested `Input` carries the checkout session id (and nothing from the webhook body that decides the outcome).
- Its first step is an Activity that re-fetches the live checkout session from Stripe, and the Workflow decides on that result: a session that has not been paid grants nothing.
- Every Activity call passes explicit `ActivityOptions` with a bounded retry budget (a `scheduleToCloseTimeout`, a `maximumAttempts`, or both).
- The Workflow does no network or database work itself and reads no `Date()`, `Date.now`, or `UUID()`.

FAIL if the Workflow trusts payment status or amounts carried in from the webhook payload, calls Stripe or entitlements directly, or leaves Activity options implicit.
