---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report orders findings by severity with a file reference on each, and lists at least one check that passed.
FAIL if it is not structured as findings followed by what passed, or a finding has no file reference.
