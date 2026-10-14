---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingWorkflows/Fulfillment/TemporalFulfillmentWorkflowClient.swift }
---

PASS if all of these hold:
- The workflow ID is derived from the checkout session id and the Stripe event id, with a service and feature prefix (for example `billing-fulfillment-<sessionId>-<eventId>`).
- The start uses an ID-reuse policy that allows a new run only after a failed one (`.allowDuplicateFailedOnly`) and a conflict policy that returns the running workflow (`.useExisting`).
- The start sets an execution timeout.

FAIL if the ID is random or ignores the session or event, a redelivered event can start a second run beside a running or completed one, or the workflow has no execution timeout.
