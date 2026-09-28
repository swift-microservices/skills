---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsCore/Documents/UseCases/CreateDocument/CreateDocumentUseCase.swift }
---

PASS if the create use case is generic over a Database whose scope adopts its use-case scope, takes subject: UserIdentity, stamps ownership from the subject, runs its repository call inside database.withTransaction, and throws its own typed error.
FAIL if it receives a connection directly, reads ServiceContext, uses an identity type named UserPayload, or takes the owner from the input.
