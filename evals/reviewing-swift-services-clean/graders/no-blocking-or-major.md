---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report has no Blocking or Major finding, and treats the internal role appended after the notes table, before the policy that names it, as a role added later rather than a finding. Minor findings and decisions for the user are fine.
FAIL if it reports any Blocking or Major defect (including the appended internal role or the intentionally omitted parts).
