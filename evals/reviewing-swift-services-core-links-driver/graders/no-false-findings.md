---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report orders findings by severity with a file reference on each, lists at least one check that passed, and does not report the tenant policy, the use case, or the intentionally omitted parts as defects.
FAIL if the tenant policy or the use case is reported as a defect, an omitted part is reported as a service defect, or nothing is listed as passed.
