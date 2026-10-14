---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a Blocking finding that the row-level security policy in Sources/NotesPostgres/Migrations/Note/CreateNotesRLSPolicy.swift has a `USING` clause but no `WITH CHECK` clause, citing that file. Adding that Postgres reuses the `USING` expression for new rows when `WITH CHECK` is omitted is correct and does not fail the case.
FAIL if the missing `WITH CHECK` is not reported, is ranked below Blocking, or has no file reference.
