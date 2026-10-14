---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists checks that passed with evidence, including the deterministic workflow ID with `.rejectDuplicate` and `.useExisting` in TemporalReservationWorkflowClient.swift, and does not report that ID policy, the worker's own database role, or the intentionally omitted parts (repositories, migrations, transport, configuration, workflow tests, delivery) as defects.
FAIL if any of those is reported as a defect, or nothing is listed as passed.
