---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a Blocking finding that the NotesCore target links PostgresNIO, citing Package.swift with a line, under the rule that a Core target never links a database driver.
FAIL if the driver dependency in Core is missing from the findings, is ranked below Blocking, or has no file reference.
