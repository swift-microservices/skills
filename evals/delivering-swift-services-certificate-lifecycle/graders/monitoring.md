---
type: llm
focus: { source: file, path: verification.md }
---

PASS if the plan monitors renewal failures (renewer logs or health), reload failures in the applications, and each leaf's remaining lifetime, with an alert early enough to act before the shortest leaf could expire.
FAIL if it has no practical renewal-failure signal. Exact lifetimes and intervals are design choices, not grading constants.
