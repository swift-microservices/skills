---
type: llm
---

PASS if the reply is a review report that (1) reports as a blocking finding that the row-level security policy in Sources/NotesPostgres/Migrations/Note/CreateNotesRLSPolicy.swift has a USING clause but no WITH CHECK clause, which the conventions make blocking, citing that file (a report may add that Postgres reuses the USING expression for new rows when WITH CHECK is omitted; that is correct and not a reason to fail), and (2) reports as a finding that CreateNoteUseCase in Sources/NotesCore/Notes/UseCases/CreateNote/CreateNoteUseCase.swift receives a PostgresConnection and runs SQL directly instead of a Database with withTransaction, citing that file, and (3) orders findings by severity with a file reference on each, and (4) lists at least one check that passed.
FAIL if either finding is missing, if a finding has no file reference, if the reviewer edits or writes repository files (recommending a fix in the report is expected and fine), or if the reply is not structured as findings followed by what passed.
