---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingWorkflows/Fulfillment/FulfillmentActivities.swift }
---

PASS if no Activity in this container registers under a name the existing `SubscriptionActivities` already uses (`fetchCheckoutSession`, `grantEntitlement`): either its methods have other names, or a clashing method sets a distinct name with `@Activity(name:)`.
FAIL if a method named `fetchCheckoutSession` or `grantEntitlement` has no distinct `@Activity(name:)`.
