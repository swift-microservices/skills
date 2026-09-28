---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksCore/Notebooks/UseCases/CreateNotebook/CreateNotebookUseCase.swift }
---

PASS if the create use case is generic over a Database whose scope adopts its use-case scope, takes subject: UserIdentity, stamps ownership from the subject rather than the input, runs its repository call inside database.withTransaction, and throws its own typed error.
FAIL if it receives a database connection or request directly, reads ServiceContext, takes the owner from the input, or runs I/O outside withTransaction.
