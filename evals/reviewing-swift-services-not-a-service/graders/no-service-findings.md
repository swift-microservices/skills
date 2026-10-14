---
type: llm
focus: trace
---

Judge the review (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the review reports no service-shape defects for this library: nothing about a missing Core, Postgres, or transport target, a missing executable, `serve`, migrations, database roles, a committed `Package.resolved`, or service CI.
FAIL if it reports any of those absences as a finding against the library, or claims to have built or tested it.
