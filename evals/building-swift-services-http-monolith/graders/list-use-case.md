---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksCore/Notebooks/UseCases/ListNotebooks/ListNotebooksUseCase.swift }
---

PASS if all of these hold:
- The use case is generic over a `Database` whose scope adopts its use-case scope, takes `subject: UserIdentity`, and reads inside `database.withTransaction`.
- It lists the caller's own notebooks and takes no user id as input; if administrators list every notebook, that is a separate use case with its own `.admin` check, not a branch in this one.

FAIL if it receives a connection or request directly, reads `ServiceContext`, branches on the subject's role to serve administrators, or relies on a controller or middleware for an administrator decision.
