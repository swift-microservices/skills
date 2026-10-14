---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a finding that CreateNoteUseCase in Sources/NotesCore/Notes/UseCases/CreateNote/CreateNoteUseCase.swift receives a `PostgresConnection` and runs SQL directly instead of taking a `Database` and working in `withTransaction`, citing that file.
FAIL if this finding is missing or has no file reference.
