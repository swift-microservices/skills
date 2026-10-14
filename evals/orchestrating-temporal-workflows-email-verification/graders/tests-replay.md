---
type: llm
focus: { source: file, path: acme-accounts/Tests/AccountsWorkflowsTests/EmailVerificationWorkflowReplayTests.swift }
---

PASS if the suite replays recorded workflow histories (JSON fixtures recorded from end-to-end runs) against the current Workflow code with `WorkflowReplayer` and fails on a replay failure.
FAIL if it only reruns the Workflow end to end, or compares source code or payload types instead of replaying histories.
