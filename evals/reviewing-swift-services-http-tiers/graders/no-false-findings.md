---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report orders findings by severity and reports the omitted parts (OpenAPI documents, persistence, use cases, configuration, lifecycle, tests, delivery) as limitations or not applicable.
FAIL if it reports an intentionally omitted part as a defect or claims to have built the package.
