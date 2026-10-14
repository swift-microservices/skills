---
type: llm
focus: { source: file, path: acme-accounts/Tests/AccountsWorkflowsTests/EmailVerificationWorkflowTests.swift }
---

PASS if the tests run the real Workflow and Activity container on the SDK's time-skipping test server (`.temporalTimeSkippingTestServer`, on this suite or a parent suite it extends), over a mock Activity service, and cover both the verified branch and the expired branch.
FAIL if they call the Workflow's `run` directly, sleep in real time, or cover only one branch.
