---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksCore/Notebooks/UseCases/ListNotebooks/ListNotebooksUseCase.swift }
---

PASS if the list use case takes subject: UserIdentity, lists the subject's own notebooks, and lets an administrator list every notebook by checking .admin in its own body (throwing its own .forbidden when a non-administrator asks for every notebook), reaching all rows through a scope only the internal-role database adopts; all I/O runs inside withTransaction.
FAIL if the administrator decision is made in a controller, middleware, or context conversion with no check in the use case, if it receives a connection or request directly, or if the identity type is not UserIdentity.
