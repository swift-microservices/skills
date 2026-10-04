---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsCore/Documents/UseCases/ListDocuments/ListDocumentsUseCase.swift }
---

PASS if all of these hold:
- The use case takes `subject: UserIdentity` and does all I/O inside `withTransaction`.
- If this use case also serves administrators listing every document, it decides that in its own body from the subject's role (choosing the internal-role database, or throwing its own `.forbidden`); serving administrators through a separate use case with its own role check is equally acceptable.

FAIL if the administrator decision is made in a gRPC handler or interceptor, or the use case receives a connection directly.
