---
type: llm
focus: { source: file, path: acme-billing/Tests/BillingWorkflowsTests/BillingWorkerRegistrationTests.swift }
---

PASS if the test builds the same Activity list the worker registers, from both the subscription and the fulfillment containers, and asserts that no Activity name appears twice, without needing a Temporal server.
FAIL if it checks only one container, hard-codes the expected names instead of reading the registered list, or only asserts the worker starts.
