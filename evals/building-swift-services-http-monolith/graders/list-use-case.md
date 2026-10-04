---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksCore/Notebooks/UseCases/ListNotebooks/ListNotebooksUseCase.swift }
---

PASS if all of these hold:
- The use case is generic over a `Database` whose scope adopts its use-case scope, takes `subject: UserIdentity`, and reads inside `database.withTransaction`.
- If it also serves administrators listing every notebook, it checks `.admin` in its own body and throws its own `.forbidden`; serving administrators through a separate use case with its own check is equally acceptable.

FAIL if it receives a connection or request directly, reads `ServiceContext`, or relies on a controller or middleware for an administrator decision it makes itself.
